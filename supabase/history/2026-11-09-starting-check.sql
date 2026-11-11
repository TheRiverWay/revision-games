-- Starting check (unthemed diagnostic) and focus topics.
-- Run in this order. Applied 2026-11-09 as migrations: starting_check_schema,
-- starting_check_functions (focus_topic_names, start_check, next_check_question, check_results),
-- starting_check_grants, next_question_focus_topics, match_event_ignore_check_answers.
-- NOT YET APPLIED: submit_check_answer and set_focus_topics (and their grants). They contain
-- DELETE statements, the Supabase tool asks for a confirmation for those and it was
-- auto-cancelled. Apply that part by hand (SQL editor) before the check page goes live.

-- ============================================================
-- 1. Schema
-- ============================================================
create table if not exists check_sessions (
  id bigint generated always as identity primary key,
  child_id uuid not null references children(id) on delete cascade,
  subject text not null default 'maths',
  tier text not null default 'Foundation',
  plan text[] not null default '{}',          -- template ids in the order they are served
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  question_count int
);
create index if not exists check_sessions_child_idx on check_sessions (child_id, started_at desc);
alter table check_sessions enable row level security;
create policy "see checks" on check_sessions for select to authenticated using (public.can_see_child(child_id));

-- Check questions live in answers next to game answers: check_id set, game_id null.
alter table answers add column if not exists check_id bigint references check_sessions(id) on delete cascade;
create index if not exists answers_check_idx on answers (check_id) where check_id is not null;
alter table answers add constraint answers_check_or_game check (check_id is null or game_id is null);

create table if not exists child_focus_topics (
  child_id uuid not null references children(id) on delete cascade,
  topic text not null,
  source text not null check (source in ('check', 'tutor', 'parent', 'admin')),
  set_at timestamptz not null default now(),
  primary key (child_id, topic)
);
alter table child_focus_topics enable row level security;
create policy "see focus topics" on child_focus_topics for select to authenticated using (public.can_see_child(child_id));

-- ============================================================
-- 2. Functions
-- ============================================================

-- The 14 v1 topics. set_focus_topics only accepts these.
create or replace function public.focus_topic_names()
returns text[] language sql immutable set search_path to 'public' as $$
  select array['Algebra','Angles','Area and perimeter','Averages','Compound measures','Decimals','Fractions',
               'Number','Percentages','Probability','Pythagoras','Ratio','Units and time','Volume']::text[];
$$;

-- Plan: per topic, 2 questions if it has 3+ usable templates, else 1 (Pythagoras, Volume).
-- First question is a random easiest template, second prefers a harder one, so 2/2 means
-- the child can do the basic and the step up. Round 1 (all the easy ones) is served before
-- round 2, topics shuffled within a round. Today that is 12 x 2 + 2 x 1 = 26 questions.
-- An unfinished check from the last 7 days is resumed instead of starting a new one.
create or replace function public.start_check(p_child uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  s check_sessions;
  v_tier text;
  v_plan text[];
  v_done int;
begin
  if not public.owns_child(p_child) then raise exception 'Child not found'; end if;

  select * into s from check_sessions
   where child_id = p_child and finished_at is null and started_at > now() - interval '7 days'
   order by started_at desc limit 1;
  if s.id is not null then
    select count(*) into v_done from answers where check_id = s.id and answered_at is not null;
    return jsonb_build_object('session_id', s.id, 'total', s.question_count, 'answered', v_done, 'resumed', true);
  end if;

  select coalesce((select tier from child_games where child_id = p_child and subject = 'maths'
                    order by created_at desc limit 1), 'Foundation') into v_tier;

  with usable as (
    select t.id, t.topic, t.difficulty, random() r
      from question_templates t
     where t.subject = 'maths' and t.tier = v_tier
       and exists (select 1 from question_variants q where q.template_id = t.id
                     and q.template_version = t.version and q.status <> 'rejected')
  ), counts as (
    select topic, count(*) n from usable group by topic
  ), first_pick as (
    select distinct on (u.topic) u.topic, u.id, u.difficulty from usable u order by u.topic, u.difficulty, u.r
  ), second_pick as (
    select distinct on (u.topic) u.topic, u.id from usable u
      join first_pick f on f.topic = u.topic and u.id <> f.id
      join counts c on c.topic = u.topic and c.n >= 3
     order by u.topic, (u.difficulty > f.difficulty) desc, u.r
  ), picks as (
    select 1 round, topic, id from first_pick
    union all
    select 2, topic, id from second_pick
  )
  select array_agg(id order by round, random()) into v_plan from picks;

  if coalesce(array_length(v_plan, 1), 0) = 0 then raise exception 'No questions available'; end if;

  insert into check_sessions (child_id, subject, tier, plan, question_count)
  values (p_child, 'maths', v_tier, v_plan, array_length(v_plan, 1))
  returning * into s;
  return jsonb_build_object('session_id', s.id, 'total', s.question_count, 'answered', 0, 'resumed', false);
end $$;

-- Serves the next planned question. If the last one served was never answered (page
-- reloaded), the same attempt is served again rather than skipping it.
create or replace function public.next_check_question(p_session bigint)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  s check_sessions;
  a answers;
  v_tpl question_templates;
  v_var question_variants;
  v_served int;
  v_id bigint;
begin
  select * into s from check_sessions where id = p_session for update;
  if s.id is null or not public.owns_child(s.child_id) then raise exception 'Check not found'; end if;
  if s.finished_at is not null then return jsonb_build_object('done', true); end if;

  select * into a from answers where check_id = s.id and answered_at is null order by served_at limit 1;
  if a.id is null then
    select count(*) into v_served from answers where check_id = s.id;
    if v_served >= s.question_count then return jsonb_build_object('done', true); end if;
    select * into v_tpl from question_templates where id = s.plan[v_served + 1];
    select * into v_var from question_variants
     where template_id = v_tpl.id and template_version = v_tpl.version and status <> 'rejected'
     order by (status = 'approved') desc, random() limit 1;
    if v_var.id is null then raise exception 'No number sets for %', v_tpl.id; end if;
    insert into answers (child_id, check_id, game_id, template_id, topic, variant_id, template_version, served_at)
    values (s.child_id, s.id, null, v_tpl.id, v_tpl.topic, v_var.id, v_tpl.version, now())
    returning * into a;
  else
    select * into v_tpl from question_templates where id = a.template_id;
    select * into v_var from question_variants where id = a.variant_id;
  end if;
  select count(*) into v_served from answers where check_id = s.id;

  return jsonb_build_object(
    'done', false, 'attempt_id', a.id, 'template_id', v_tpl.id, 'topic', v_tpl.topic,
    'difficulty', v_tpl.difficulty, 'calculator', v_tpl.calculator, 'vars', v_var.vars,
    'number', v_served, 'total', s.question_count,
    'wording', coalesce((select wording from theme_wording where template_id = v_tpl.id and theme = 'generic'), v_tpl.spec_point));
end $$;

-- Per-topic results. Rating rule (percent = correct / answered in that topic):
--   secure >= 75%, shaky >= 40% and < 75%, gap < 40%.
--   With 2 questions: 2/2 secure, 1/2 shaky, 0/2 gap. With 1 question: 1/1 secure, 0/1 gap.
-- Suggested focus topics = the gap topics. Parents, tutors with consent and admins can read.
create or replace function public.check_results(p_session bigint)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  s check_sessions;
  v_topics jsonb;
begin
  select * into s from check_sessions where id = p_session;
  if s.id is null or not (public.can_see_child(s.child_id) or public.is_admin()) then raise exception 'Check not found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('topic', topic, 'asked', asked, 'correct', correct,
           'percent', pct, 'rating', case when pct >= 75 then 'secure' when pct >= 40 then 'shaky' else 'gap' end)
           order by topic), '[]')
    into v_topics
    from (select topic, count(*) asked, count(*) filter (where correct) correct,
                 round(100.0 * count(*) filter (where correct) / count(*))::int pct
            from answers where check_id = s.id and answered_at is not null
           group by topic) x;

  return jsonb_build_object(
    'session_id', s.id, 'child_id', s.child_id, 'started_at', s.started_at, 'finished_at', s.finished_at,
    'finished', s.finished_at is not null, 'total', s.question_count,
    'answered', (select count(*) from answers where check_id = s.id and answered_at is not null),
    'correct', (select count(*) from answers where check_id = s.id and correct),
    'topics', v_topics,
    'suggested_focus', coalesce((select jsonb_agg(t ->> 'topic' order by t ->> 'topic') from jsonb_array_elements(v_topics) t
                                  where t ->> 'rating' = 'gap'), '[]'),
    'focus_topics', coalesce((select jsonb_agg(jsonb_build_object('topic', topic, 'source', source) order by topic)
                                from child_focus_topics where child_id = s.child_id), '[]'));
end $$;

-- Marks a check answer. No credits, no rank, no spaced repetition, and no answer or working
-- in the reply. Finishing the last question writes the gap topics as 'check' focus topics,
-- replacing earlier 'check' rows; tutor/parent/admin rows are never touched.
create or replace function public.submit_check_answer(p_attempt bigint, p_given text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  a answers;
  s check_sessions;
  ok boolean;
  v_answered int;
  r jsonb;
begin
  select * into a from answers where id = p_attempt for update;
  if a.id is null or a.check_id is null or not public.owns_child(a.child_id) then raise exception 'Question not found'; end if;
  if a.answered_at is not null then raise exception 'Already answered'; end if;
  select * into s from check_sessions where id = a.check_id for update;
  if s.finished_at is not null then raise exception 'That check is finished'; end if;

  ok := coalesce(public.answer_is_correct(a.variant_id, p_given), false);
  update answers set answered_at = now(), given_text = left(p_given, 200),
         given_answer = public.answer_as_number(p_given), correct = ok
   where id = p_attempt;

  select count(*) into v_answered from answers where check_id = s.id and answered_at is not null;
  if v_answered >= s.question_count then
    update check_sessions set finished_at = now() where id = s.id;
    r := public.check_results(s.id);
    delete from child_focus_topics where child_id = s.child_id and source = 'check';
    insert into child_focus_topics (child_id, topic, source)
    select s.child_id, x, 'check' from jsonb_array_elements_text(r -> 'suggested_focus') x
    on conflict (child_id, topic) do nothing;
  end if;

  return jsonb_build_object('correct', ok, 'done', v_answered >= s.question_count,
                            'number', v_answered, 'total', s.question_count);
end $$;

-- Sets the child's whole focus list (it replaces every row, the check's suggestions included,
-- so a tutor can drop a topic the check suggested). Parent -> 'parent', tutor with consent ->
-- 'tutor', admin -> 'admin'. Empty array or null clears the list.
create or replace function public.set_focus_topics(p_child uuid, p_topics text[])
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_source text;
  v_bad text;
begin
  if public.owns_child(p_child) then v_source := 'parent';
  elsif exists (select 1 from children where id = p_child and tutor_id = auth.uid() and tutor_consent_at is not null) then v_source := 'tutor';
  elsif public.is_admin() and exists (select 1 from children where id = p_child) then v_source := 'admin';
  else raise exception 'Child not found';
  end if;

  select x into v_bad from unnest(coalesce(p_topics, '{}')) x where x is null or not (x = any (public.focus_topic_names())) limit 1;
  if found then raise exception 'Unknown topic: %', coalesce(v_bad, 'empty'); end if;

  delete from child_focus_topics where child_id = p_child;
  insert into child_focus_topics (child_id, topic, source)
  select distinct p_child, x, v_source from unnest(coalesce(p_topics, '{}')) x;
end $$;

revoke execute on function public.focus_topic_names() from public, anon;
revoke execute on function public.start_check(uuid) from public, anon;
revoke execute on function public.next_check_question(bigint) from public, anon;
revoke execute on function public.check_results(bigint) from public, anon;
revoke execute on function public.submit_check_answer(bigint, text) from public, anon;
revoke execute on function public.set_focus_topics(uuid, text[]) from public, anon;
grant execute on function public.focus_topic_names() to authenticated;
grant execute on function public.start_check(uuid) to authenticated;
grant execute on function public.next_check_question(bigint) to authenticated;
grant execute on function public.check_results(bigint) to authenticated;
grant execute on function public.submit_check_answer(bigint, text) to authenticated;
grant execute on function public.set_focus_topics(uuid, text[]) to authenticated;

-- ============================================================
-- 3. next_question steers towards focus topics
-- ============================================================
-- Unchanged except one step: when no due review was picked (and it isn't a retry of a
-- specific template), a child with focus topics gets a focus-topic template half the time.
-- If no focus template fits, it falls through to the normal pick.
create or replace function public.next_question(p_game uuid, p_template text default null::text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  g child_games;
  v_tpl question_templates;
  v_var question_variants;
  v_last text;
  v_last_var bigint;
  v_id bigint;
begin
  select * into g from child_games where id = p_game;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  select template_id, variant_id into v_last, v_last_var from answers
   where child_id = g.child_id order by served_at desc limit 1;

  if p_template is not null then
    select * into v_tpl from question_templates where id = p_template and subject = g.subject;
  else
    if random() < 0.7 then
      select t.* into v_tpl
        from child_mastery m join question_templates t on t.id = m.template_id
       where m.child_id = g.child_id and m.next_review_at <= now()
         and t.subject = g.subject and t.tier = g.tier and t.id is distinct from v_last
         and exists (select 1 from question_variants q where q.template_id = t.id
                       and q.template_version = t.version and q.status <> 'rejected')
       order by m.box, m.next_review_at limit 1;
    end if;
    if v_tpl.id is null and random() < 0.5
       and exists (select 1 from child_focus_topics f where f.child_id = g.child_id) then
      select t.* into v_tpl
        from question_templates t
       where t.subject = g.subject and t.tier = g.tier and t.id is distinct from v_last
         and t.topic in (select f.topic from child_focus_topics f where f.child_id = g.child_id)
         and exists (select 1 from question_variants q where q.template_id = t.id
                       and q.template_version = t.version and q.status <> 'rejected')
       order by exists (select 1 from child_mastery m where m.child_id = g.child_id and m.template_id = t.id),
                random()
       limit 1;
    end if;
    if v_tpl.id is null then
      select t.* into v_tpl
        from question_templates t
       where t.subject = g.subject and t.tier = g.tier and t.id is distinct from v_last
         and exists (select 1 from question_variants q where q.template_id = t.id
                       and q.template_version = t.version and q.status <> 'rejected')
       order by exists (select 1 from child_mastery m where m.child_id = g.child_id and m.template_id = t.id),
                random()
       limit 1;
    end if;
  end if;
  if v_tpl.id is null then raise exception 'No questions available'; end if;

  select * into v_var from question_variants
   where template_id = v_tpl.id and template_version = v_tpl.version and status <> 'rejected'
   order by (status = 'approved') desc, (id = v_last_var) is true, random()
   limit 1;
  if v_var.id is null then raise exception 'No number sets for %', v_tpl.id; end if;

  insert into answers (child_id, game_id, template_id, topic, variant_id, template_version, served_at)
  values (g.child_id, g.id, v_tpl.id, v_tpl.topic, v_var.id, v_tpl.version, now())
  returning id into v_id;

  return jsonb_build_object(
    'attempt_id', v_id, 'template_id', v_tpl.id, 'topic', v_tpl.topic,
    'spec_point', v_tpl.spec_point, 'difficulty', v_tpl.difficulty,
    'calculator', v_tpl.calculator, 'vars', v_var.vars, 'tip', v_tpl.template ->> 'tip');
end $function$;

-- ============================================================
-- 4. match_event: check answers (game_id null) must never count for a match.
-- ============================================================
-- The old test "a.game_id <> m.game_id" is null (not true) when game_id is null, so a
-- check answer would have slipped through. One-token fix, rest of the function unchanged.
do $$
declare d text;
begin
  select pg_get_functiondef('public.match_event(bigint, bigint)'::regprocedure) into d;
  if position('a.game_id <> m.game_id' in d) > 0 then
    execute replace(d, 'a.game_id <> m.game_id', 'a.game_id is distinct from m.game_id');
  end if;
end $$;

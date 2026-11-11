-- LevelWise schema, part 2: functions.
-- Exported from the live Supabase project on 2026-11-10 (pg_get_functiondef). Run after 01_tables.sql.
-- Every trusted action (serving and marking questions, rewards, crates, admin, review) is a
-- SECURITY DEFINER function with a fixed search_path; grants are set in 03_security.sql.
-- Requires the pgcrypto extension (crypt, gen_salt) in the extensions schema, as on Supabase.

set search_path to public;
set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.admin_add_child(p_parent uuid, p_nickname text, p_pin text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare v_id uuid; v_name text := btrim(coalesce(p_nickname, ''));
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  if not exists (select 1 from parents where id = p_parent) then raise exception 'Parent not found'; end if;
  if length(v_name) < 1 or length(v_name) > 20 then raise exception 'Name must be 1 to 20 characters'; end if;
  if p_pin is not null and p_pin <> '' and p_pin !~ '^[0-9]{4}$' then raise exception 'PIN must be 4 digits'; end if;
  insert into children (parent_id, nickname) values (p_parent, v_name) returning id into v_id;
  if p_pin is not null and p_pin <> '' then
    insert into child_pins (child_id, pin_hash) values (v_id, crypt(p_pin, gen_salt('bf')));
  end if;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_delete_account(p_request bigint, p_confirm_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r account_deletion_requests; v_email text;
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  select * into r from account_deletion_requests where id = p_request and cancelled_at is null and done_at is null for update;
  if r.id is null or r.user_id is null then raise exception 'No open request with that id'; end if;
  select email into v_email from auth.users where id = r.user_id;
  if lower(trim(p_confirm_email)) is distinct from lower(v_email) then raise exception 'Email does not match the account'; end if;
  if r.user_id = auth.uid() then raise exception 'You cannot delete your own admin account here'; end if;
  if exists (select 1 from tutors where id = r.user_id) then raise exception 'This account is a tutor. Remove the tutor role first'; end if;
  update account_deletion_requests set done_at = now() where id = r.id;
  delete from auth.users where id = r.user_id;
  return jsonb_build_object('deleted', v_email, 'request', r.id);
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_deletion_requests()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user_id', r.user_id, 'email', r.email, 'reason', r.reason,
      'requested_at', r.requested_at, 'delete_by', r.requested_at + interval '30 days',
      'children', (select count(*) from children c where c.parent_id = r.user_id)) order by r.requested_at)
    from account_deletion_requests r where r.cancelled_at is null and r.done_at is null), '[]'::jsonb);
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_make_tutor(p_email text, p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  if coalesce(trim(p_name),'') = '' or char_length(trim(p_name)) > 60 then raise exception 'Give a name up to 60 characters'; end if;
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception 'No account with that email. Ask them to sign up first.'; end if;
  insert into tutors (id, name) values (v_id, trim(p_name)) on conflict (id) do update set name = excluded.name;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'email', u.email, 'display_name', p.display_name, 'created_at', p.created_at,
      'children', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', c.id, 'nickname', c.nickname, 'created_at', c.created_at,
          'has_pin', exists (select 1 from child_pins cp where cp.child_id = c.id),
          'tutor_id', c.tutor_id, 'tutor_consent', c.tutor_consent_at is not null,
          'games', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', g.id, 'theme', g.theme, 'flavour', g.flavour, 'custom_names', g.custom_names,
              'exam_board', g.exam_board, 'tier', g.tier, 'rank_tier', g.rank_tier, 'rank_level', g.rank_level,
              'credits', g.credits, 'created_at', g.created_at,
              'last_played', (select max(a.answered_at) from answers a where a.game_id = g.id),
              'answered_7d', (select count(*) from answers a where a.game_id = g.id and a.answered_at > now() - interval '7 days'))
              order by g.created_at)
            from child_games g where g.child_id = c.id), '[]'::jsonb),
          'focus_topics', coalesce((select jsonb_agg(f.topic order by f.topic) from child_focus_topics f where f.child_id = c.id), '[]'::jsonb),
          'last_check', (select jsonb_build_object('id', s.id, 'started_at', s.started_at, 'finished_at', s.finished_at)
                           from check_sessions s where s.child_id = c.id order by s.started_at desc limit 1))
          order by c.created_at)
        from children c where c.parent_id = p.id), '[]'::jsonb))
      order by p.created_at desc)
    from parents p left join auth.users u on u.id = p.id), '[]'::jsonb);
end $function$
;
CREATE OR REPLACE FUNCTION public.answer_as_number(s text)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  t text := public.clean_answer(s);
  m text[];
begin
  t := regexp_replace(t, '[£€$%]', '', 'g');
  -- hours and minutes: "2 hrs 30 mins", "1hr 30min", "2h 30"
  m := regexp_match(t, '^([0-9]+)\s*(?:hours?|hrs?|h)\s*([0-9]+)\s*(?:minutes?|mins?|m)?$');
  if m is not null then return m[1]::numeric + m[2]::numeric / 60; end if;
  m := regexp_match(t, '^(-?[0-9]+)[[:space:]]+([0-9]+)[[:space:]]*/[[:space:]]*([0-9]+)$');
  if m is not null and m[3]::numeric <> 0 then
    return m[1]::numeric + sign(m[1]::numeric + 0.5) * m[2]::numeric / m[3]::numeric;
  end if;
  t := regexp_replace(t, '[[:space:]]', '', 'g');
  m := regexp_match(t, '^(-?[0-9]+)/([0-9]+)$');
  if m is not null and m[2]::numeric <> 0 then return m[1]::numeric / m[2]::numeric; end if;
  t := regexp_replace(t, '([0-9]),([0-9]{3})', '\1\2', 'g');
  -- square and cubic units typed plainly: m2, cm3, km2
  t := regexp_replace(t, '([0-9.])(mm|cm|km|m)\^?[23]$', '\1');
  t := regexp_replace(t, '(cm|mm|km|kg|ml|m/s|km/h|mph|hours?|hrs?|h|m|g|l|k|degrees|deg|°|units?|squared|cubed|²|³|\^2|\^3|thousand|million)+$', '');
  if t ~ '^-?[0-9]*\.?[0-9]+$' then return t::numeric; end if;
  return null;
end $function$
;
CREATE OR REPLACE FUNCTION public.answer_is_correct(p_variant bigint, p_given text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare v question_variants; t question_templates; given_norm text; given_num numeric;
begin
  select * into v from question_variants where id = p_variant;
  select * into t from question_templates where id = v.template_id;
  given_norm := public.normalise_answer(p_given);
  given_num := public.answer_as_number(p_given);
  if given_norm = '' then return false; end if;
  if given_norm = any (select public.normalise_answer(x) from unnest(v.accept || v.answer_text) x) then return true; end if;
  if v.answer is null and t.topic in ('Ratio', 'Averages') and public.number_list_match(p_given, v.answer_text) then return true; end if;
  if not v.exact_only and v.answer is not null and given_num is not null then
    -- probabilities may be given as a percentage (AQA accepts 20% for 1/5)
    if t.topic = 'Probability' and p_given ~ '%' and v.answer between 0 and 1 then
      return abs(given_num / 100 - v.answer) <= v.tolerance;
    end if;
    return abs(given_num - v.answer) <= v.tolerance;
  end if;
  return false;
end $function$
;
CREATE OR REPLACE FUNCTION public.answer_numbers(s text, comma_thousands boolean)
 RETURNS numeric[]
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare tok text; part text; result numeric[] := '{}';
begin
  for tok in select m[1] from regexp_matches(coalesce(s, ''), '([0-9][0-9,]*(?:\.[0-9]+)?)', 'g') m loop
    tok := trim(both ',' from tok);
    if comma_thousands and tok ~ '^[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$' then
      result := result || replace(tok, ',', '')::numeric;
    else
      foreach part in array string_to_array(tok, ',') loop
        if part ~ '^[0-9]+(\.[0-9]+)?$' then result := result || part::numeric; end if;
      end loop;
    end if;
  end loop;
  return result;
end $function$
;
CREATE OR REPLACE FUNCTION public.assign_game(p_child uuid, p_theme text, p_flavour text DEFAULT NULL::text, p_custom_names jsonb DEFAULT '{}'::jsonb, p_colours jsonb DEFAULT '{}'::jsonb, p_exam_board text DEFAULT 'AQA'::text, p_tier text DEFAULT 'Foundation'::text, p_focus_topics text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t themes; f theme_flavours; g child_games;
  v_admin boolean := public.is_admin();
  v_names jsonb := '{}'::jsonb; fld jsonb; v_val text; v_created boolean := false;
begin
  if not exists (select 1 from children where id = p_child) then raise exception 'Child not found'; end if;
  select * into t from themes where id = p_theme;
  if t.id is null or t.status = 'system' then raise exception 'Unknown theme'; end if;
  if not (v_admin or (public.owns_child(p_child) and t.status = 'live')) then raise exception 'Child not found'; end if;
  if coalesce(p_exam_board, 'AQA') not in ('AQA', 'Edexcel', 'OCR') then raise exception 'Exam board must be AQA, Edexcel or OCR'; end if;
  if coalesce(p_tier, 'Foundation') <> 'Foundation' then raise exception 'Only Foundation tier is available'; end if;

  -- keep only the name fields this theme asks for
  for fld in select * from jsonb_array_elements(coalesce(t.custom_name_fields, '[]'::jsonb)) loop
    v_val := btrim(coalesce(p_custom_names ->> (fld ->> 'key'), ''));
    if length(v_val) > 24 then raise exception '% must be 24 characters or fewer', fld ->> 'label'; end if;
    if v_val <> '' then v_names := v_names || jsonb_build_object(fld ->> 'key', v_val); end if;
  end loop;

  select * into g from child_games where child_id = p_child and theme = p_theme and subject = 'maths';

  if p_flavour is not null and p_flavour <> '' then
    select * into f from theme_flavours where id = p_flavour and theme = p_theme;
    if f.id is null then raise exception 'That venture is not part of this theme'; end if;
    if f.unlock_tier > coalesce(g.rank_tier, 1) then raise exception 'That venture is not unlocked yet'; end if;
  end if;

  if g.id is null then
    insert into child_games (child_id, subject, theme, custom_names, colours, exam_board, tier, flavour)
    values (p_child, 'maths', p_theme, v_names, coalesce(p_colours, '{}'::jsonb), coalesce(p_exam_board, 'AQA'), 'Foundation', f.id)
    returning * into g;
    v_created := true;
  else
    update child_games set custom_names = custom_names || v_names, colours = colours || coalesce(p_colours, '{}'::jsonb),
           exam_board = coalesce(p_exam_board, exam_board), flavour = coalesce(f.id, flavour)
     where id = g.id returning * into g;
  end if;

  if p_focus_topics is not null then perform public.set_focus_topics(p_child, p_focus_topics); end if;

  return jsonb_build_object('game_id', g.id, 'created', v_created, 'theme', g.theme, 'flavour', g.flavour,
                            'custom_names', g.custom_names, 'exam_board', g.exam_board);
end $function$
;
CREATE OR REPLACE FUNCTION public.can_see_child(c uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from children where id = c
    and (parent_id = auth.uid()
         or (tutor_id = auth.uid() and tutor_consent_at is not null)));
$function$
;
CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update account_deletion_requests set cancelled_at = now()
   where user_id = auth.uid() and cancelled_at is null and done_at is null;
  return found;
end $function$
;
CREATE OR REPLACE FUNCTION public.check_child_pin(p_child uuid, p_pin text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare h text;
begin
  if not public.owns_child(p_child) then return false; end if;
  select pin_hash into h from child_pins where child_id = p_child;
  return h is null or h = crypt(coalesce(p_pin, ''), h);
end $function$
;
CREATE OR REPLACE FUNCTION public.check_results(p_session bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;
CREATE OR REPLACE FUNCTION public.children_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.tutor_id is distinct from old.tutor_id
     and new.tutor_consent_at is not distinct from old.tutor_consent_at then
    new.tutor_consent_at := null;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.choose_venture(p_game uuid, p_flavour text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g child_games; f theme_flavours;
begin
  select * into g from child_games where id = p_game for update;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  select * into f from theme_flavours where id = p_flavour and theme = g.theme;
  if f.id is null then raise exception 'That venture is not part of this game'; end if;
  if f.unlock_tier > g.rank_tier then raise exception 'You have not unlocked that venture yet'; end if;
  update child_games set flavour = f.id where id = p_game;
  return jsonb_build_object('flavour', f.id, 'name', f.name, 'words', f.words);
end $function$
;
CREATE OR REPLACE FUNCTION public.clean_answer(s text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select regexp_replace(regexp_replace(regexp_replace(regexp_replace(
           translate(lower(coalesce(s, '')), '−–—×', '---x'),
         '^\s*[a-z ]{1,16}=\s*(?=[-0-9.£€$])', ''),
         '([0-9])\s*[x*]\s*n\y', '\1n', 'g'),
         '\s*\.\s*$', ''),
         '^\s+|\s+$', '', 'g');
$function$
;
CREATE OR REPLACE FUNCTION public.dev_add_credits(p_game uuid, p_amount integer DEFAULT 500)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g child_games;
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  select * into g from child_games where id = p_game;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  update child_games set credits = credits + least(greatest(p_amount, 0), 10000) where id = p_game returning credits into g.credits;
  return g.credits;
end $function$
;
CREATE OR REPLACE FUNCTION public.dev_answer(p_attempt bigint)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r text;
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  select v.answer_text into r from answers a join question_variants v on v.id = a.variant_id where a.id = p_attempt;
  return r;
end $function$
;
CREATE OR REPLACE FUNCTION public.ensure_team(p_game uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g child_games;
begin
  select * into g from child_games where id = p_game;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  if not exists (select 1 from child_collection where game_id = p_game) then
    insert into child_collection (game_id, child_id, collectible_id, in_lineup)
    select p_game, g.child_id, id, true from collectibles where theme = g.theme and rarity = 'common' order by random() limit 5;
  elsif not exists (select 1 from child_collection where game_id = p_game and in_lineup) then
    update child_collection set in_lineup = true where game_id = p_game and collectible_id in (
      select cc.collectible_id from child_collection cc join collectibles c on c.id = cc.collectible_id
       where cc.game_id = p_game
       order by case c.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end desc, c.id limit 5);
  end if;
end $function$
;
CREATE OR REPLACE FUNCTION public.equip_item(p_game uuid, p_item text, p_slot text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s text;
begin
  if not public.owns_game(p_game) then raise exception 'Game not found'; end if;
  select coalesce(p_slot, c.slot) into s from child_collection cc join collectibles c on c.id = cc.collectible_id
   where cc.game_id = p_game and cc.collectible_id = p_item;
  if not found then raise exception 'You do not own that item'; end if;
  if s is null then raise exception 'That item has no slot'; end if;
  update child_collection set equipped_slot = null where game_id = p_game and equipped_slot = s;
  update child_collection set equipped_slot = s where game_id = p_game and collectible_id = p_item;
end $function$
;
CREATE OR REPLACE FUNCTION public.finish_match(p_match bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m matches; g child_games; th themes; f record;
  award int; bonus int := 0; pos int; promoted boolean := false; tbl jsonb;
  ra int; rb int; max_tier int;
begin
  select * into m from matches where id = p_match for update;
  select * into g from child_games where id = m.game_id for update;
  select * into th from themes where id = g.theme;
  max_tier := coalesce(array_length(th.tier_names, 1), 1);

  insert into league_results values (m.game_id, m.season, m.tier, m.round, 0, ((6 + m.round) % 7) + 1, m.our_goals, m.their_goals);
  for f in select * from public.league_fixtures(m.round) where home <> 0 and away <> 0 loop
    ra := (public.league_team_at(g.theme, m.tier, f.home)).rating;
    rb := (public.league_team_at(g.theme, m.tier, f.away)).rating;
    insert into league_results values (m.game_id, m.season, m.tier, m.round, f.home, f.away,
                                       public.sim_goals(ra, rb), public.sim_goals(rb, ra));
  end loop;

  award := case when m.our_goals > m.their_goals then 30 when m.our_goals = m.their_goals then 10 else 0 end;

  if m.round = 6 then
    tbl := public.league_table(m.game_id, m.season, m.tier);
    select o into pos from jsonb_array_elements(tbl) with ordinality e(t, o) where (t ->> 'me')::boolean;
    bonus := case pos when 1 then 100 when 2 then 60 when 3 then 25 when 4 then 25 else 0 end;
    promoted := pos <= 2 and g.rank_tier < max_tier;
    update matches set season_end = jsonb_build_object(
        'position', pos, 'bonus', bonus, 'promoted', promoted,
        'tier_name', th.tier_names[m.tier], 'new_tier_name', th.tier_names[case when promoted then m.tier + 1 else m.tier end],
        'champions', pos = 1, 'table', tbl)
     where id = m.id;
    update child_games set season = season + 1,
           rank_tier = case when promoted then rank_tier + 1 else rank_tier end,
           rank_level = case when promoted then 1 else rank_level end
     where id = g.id;
  end if;

  update matches set status = 'done', finished_at = now(), credits_awarded = award + bonus where id = m.id;
  update child_games set credits = credits + award + bonus where id = g.id;
end $function$
;
CREATE OR REPLACE FUNCTION public.focus_topic_names()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select array['Algebra','Angles','Area and perimeter','Averages','Compound measures','Decimals','Fractions',
               'Number','Percentages','Probability','Pythagoras','Ratio','Units and time','Volume']::text[];
$function$
;
CREATE OR REPLACE FUNCTION public.game_perks(p_game uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g child_games;
  result jsonb := '{"coin_bonus":0,"free_hints":0,"streak_shields":0}'::jsonb;
  r record;
begin
  select * into g from child_games where id = p_game;
  if g.id is null or not public.can_see_child(g.child_id) then raise exception 'Game not found'; end if;
  for r in
    select e.key, sum(e.value::numeric) as amount
      from child_collection cc join collectibles c on c.id = cc.collectible_id,
           jsonb_each_text(c.perks - 'stats') e
     where cc.game_id = p_game and cc.equipped_slot is not null and c.kind = 'gear'
       and e.key in ('coin_bonus', 'free_hints', 'streak_shields')
     group by e.key
  loop
    result := jsonb_set(result, array[r.key], to_jsonb((result ->> r.key)::numeric + r.amount));
  end loop;
  for r in
    select tr.effect, (select count(*) from unnest(tr.thresholds) t where t <= st.total) as rungs
      from theme_stat_rules tr
      join (select s.key as stat, sum(s.value::numeric) as total
              from child_collection cc join collectibles c on c.id = cc.collectible_id,
                   jsonb_each_text(c.perks -> 'stats') s
             where cc.game_id = p_game and cc.equipped_slot is not null and c.kind = 'gear'
             group by s.key) st on st.stat = tr.stat
     where tr.theme = g.theme
  loop
    result := jsonb_set(result, array[r.effect], to_jsonb((result ->> r.effect)::numeric + r.rungs));
  end loop;
  return jsonb_set(result, '{coin_bonus}', to_jsonb(least((result ->> 'coin_bonus')::numeric, 8)));
end $function$
;
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.parents (id) values (new.id) on conflict (id) do nothing;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from admins where user_id = auth.uid());
$function$
;
CREATE OR REPLACE FUNCTION public.is_reviewer()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_admin() or exists (select 1 from tutors where id = auth.uid());
$function$
;
CREATE OR REPLACE FUNCTION public.league_fixtures(p_round integer)
 RETURNS TABLE(home integer, away integer)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  with arr as (select array[0] || array(select ((k - 1 + p_round) % 7) + 1 from generate_series(1, 7) k) a)
  select a[i + 1], a[8 - i] from arr, generate_series(0, 3) i;
$function$
;
CREATE OR REPLACE FUNCTION public.league_info(p_game uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g child_games; th themes; played int; live bigint;
begin
  select * into g from child_games where id = p_game;
  if g.id is null or not public.can_see_child(g.child_id) then raise exception 'Game not found'; end if;
  select * into th from themes where id = g.theme;
  select count(distinct round) into played from league_results where game_id = p_game and season = g.season and tier = g.rank_tier;
  select id into live from matches where game_id = p_game and status = 'live';
  return jsonb_build_object(
    'season', g.season, 'tier', g.rank_tier, 'tier_name', th.tier_names[g.rank_tier],
    'played', played, 'rounds', 7, 'rating', public.team_rating(p_game),
    'lineup', coalesce((select jsonb_agg(collectible_id) from child_collection where game_id = p_game and in_lineup), '[]'::jsonb),
    'next_opponent', (select jsonb_build_object('name', lt.name, 'rating', lt.rating)
                        from public.league_team_at(g.theme, g.rank_tier, ((6 + played) % 7) + 1) lt),
    'live_match', case when live is not null then public.match_json(live) end,
    'table', public.league_table(p_game, g.season, g.rank_tier));
end $function$
;
CREATE OR REPLACE FUNCTION public.league_table(p_game uuid, p_season integer, p_tier integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with g as (select * from child_games where id = p_game),
  teams as (
    select 0 as idx, coalesce(nullif(g.custom_names ->> 'team', ''), 'Your club') as name, true as me from g
    union all
    select case when rn = 1 then 7 else rn - 1 end, name, false
      from (select lt.name, (row_number() over (order by lt.id))::int rn
              from league_teams lt, g where lt.theme = g.theme and lt.tier = p_tier) x),
  r as (select * from league_results where game_id = p_game and season = p_season and tier = p_tier),
  rows as (
    select home as idx, home_goals as gf, away_goals as ga from r
    union all select away, away_goals, home_goals from r),
  agg as (
    select t.idx, t.name, t.me,
           count(rows.idx)::int p,
           count(*) filter (where rows.gf > rows.ga)::int w,
           count(*) filter (where rows.gf = rows.ga)::int d,
           count(*) filter (where rows.gf < rows.ga)::int l,
           coalesce(sum(rows.gf), 0)::int gf, coalesce(sum(rows.ga), 0)::int ga
      from teams t left join rows on rows.idx = t.idx
     group by t.idx, t.name, t.me)
  select coalesce(jsonb_agg(jsonb_build_object('name', name, 'me', me, 'p', p, 'w', w, 'd', d, 'l', l,
                                               'gf', gf, 'ga', ga, 'pts', w * 3 + d)
                            order by w * 3 + d desc, gf - ga desc, gf desc, me desc, name), '[]'::jsonb)
    from agg;
$function$
;
CREATE OR REPLACE FUNCTION public.league_team_at(p_theme text, p_tier integer, p_idx integer)
 RETURNS league_teams
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select * from league_teams where theme = p_theme and tier = p_tier order by id offset p_idx % 7 limit 1;
$function$
;
CREATE OR REPLACE FUNCTION public.match_event(p_match bigint, p_attempt bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m matches; a answers; opp league_teams; n int; minute int;
  ours boolean; rushed boolean; p numeric; goal boolean; scorer text;
begin
  select * into m from matches where id = p_match for update;
  if m.id is null or not public.owns_game(m.game_id) then raise exception 'Match not found'; end if;
  if m.status <> 'live' then raise exception 'That match is over'; end if;
  n := jsonb_array_length(m.events);
  if n >= 6 then raise exception 'That match is over'; end if;
  select * into a from answers where id = p_attempt for update;
  if a.id is null or a.game_id is distinct from m.game_id or a.answered_at is null or a.match_id is not null or a.served_at < m.created_at then
    raise exception 'That answer cannot count for this match';
  end if;
  update answers set match_id = m.id where id = a.id;

  select * into opp from league_teams where id = m.opponent_id;
  minute := (array[8, 22, 37, 53, 68, 83])[n + 1] + floor(random() * 6)::int;
  rushed := a.correct and a.answered_at - a.served_at < interval '2 seconds';
  ours := a.correct and not rushed;
  if ours then
    p := least(greatest(0.55 + 0.04 * (m.our_rating - opp.rating), 0.25), 0.9);
  else
    p := least(greatest(0.40 + 0.04 * (opp.rating - m.our_rating), 0.15), 0.8);
  end if;
  goal := not rushed and random() < p;
  if ours and goal then
    select c.name into scorer from child_collection cc join collectibles c on c.id = cc.collectible_id
     where cc.game_id = m.game_id and cc.in_lineup order by random() limit 1;
  end if;

  update matches set
    events = events || jsonb_build_object('minute', minute, 'side', case when a.correct then 'us' else 'them' end,
                                          'goal', goal, 'scorer', scorer, 'rushed', rushed),
    our_goals = our_goals + (ours and goal)::int,
    their_goals = their_goals + ((not a.correct) and goal)::int
  where id = m.id returning * into m;

  if jsonb_array_length(m.events) >= 6 then perform public.finish_match(m.id); end if;
  return public.match_json(m.id);
end $function$
;
CREATE OR REPLACE FUNCTION public.match_json(p_match bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', m.id, 'round', m.round + 1, 'rounds', 7, 'status', m.status,
    'our_goals', m.our_goals, 'their_goals', m.their_goals, 'events', m.events,
    'questions', 6, 'our_rating', m.our_rating,
    'opponent', lt.name, 'their_rating', lt.rating,
    'credits_awarded', m.credits_awarded, 'season_end', m.season_end)
  from matches m join league_teams lt on lt.id = m.opponent_id where m.id = p_match;
$function$
;
CREATE OR REPLACE FUNCTION public.my_account()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'email', (select email from auth.users where id = auth.uid()),
    'children', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'nickname', c.nickname,
        'games', (select count(*) from child_games g where g.child_id = c.id)) order by c.created_at)
      from children c where c.parent_id = auth.uid()), '[]'::jsonb),
    'is_tutor', exists (select 1 from tutors where id = auth.uid()),
    'deletion', (select jsonb_build_object('requested_at', r.requested_at, 'delete_by', r.requested_at + interval '30 days')
      from account_deletion_requests r where r.user_id = auth.uid() and r.cancelled_at is null and r.done_at is null));
$function$
;
CREATE OR REPLACE FUNCTION public.next_check_question(p_session bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s check_sessions;
  a answers;
  v_tpl question_templates;
  v_var question_variants;
  v_served int;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.next_question(p_game uuid, p_template text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;
CREATE OR REPLACE FUNCTION public.normalise_answer(s text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select regexp_replace(regexp_replace(public.clean_answer(s), '[[:space:]£€$]', '', 'g'),
                        '([0-9])(k|m)(?=$|[^a-z]|and)', '\1', 'g');
$function$
;
CREATE OR REPLACE FUNCTION public.number_list_match(given text, expected text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select cardinality(public.answer_numbers(expected, false)) >= 2
     and (public.answer_numbers(given, true) = public.answer_numbers(expected, false)
       or public.answer_numbers(given, false) = public.answer_numbers(expected, false));
$function$
;
CREATE OR REPLACE FUNCTION public.open_crate(p_game uuid, p_crate text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g child_games;
  c crates;
  total_odds numeric;
  roll numeric;
  rar text;
  item collectibles;
  got jsonb := '[]'::jsonb;
  i int;
  force_leg boolean;
  force_epic boolean;
  got_epic boolean := false;
  got_leg boolean := false;
  pity_epic int;
  pity_leg int;
begin
  select * into g from child_games where id = p_game for update;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  select * into c from crates
   where id = p_crate and active
     and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now());
  if c.id is null then raise exception 'That crate is not available'; end if;
  if g.theme <> c.theme then raise exception 'That crate is for a different game'; end if;
  if g.credits < c.price then raise exception 'Not enough %', (select currency_name from themes where id = g.theme); end if;
  update child_games set credits = credits - c.price where id = p_game;

  -- guarantees: an epic or better by the 10th crate, a legendary by the 40th
  force_leg := g.crates_since_legendary >= 39
               and exists (select 1 from collectibles where theme = c.theme and rarity = 'legendary' and unlock_tier <= g.rank_tier);
  force_epic := not force_leg and g.crates_since_epic >= 9
               and exists (select 1 from collectibles where theme = c.theme and rarity = 'epic' and unlock_tier <= g.rank_tier);

  select sum(value::numeric) into total_odds from jsonb_each_text(c.odds);
  for i in 1 .. c.items_per_crate loop
    if i = 1 and force_leg then rar := 'legendary';
    elsif i = 1 and force_epic then rar := 'epic';
    else
      roll := random() * total_odds;
      select k into rar from (
        select key as k, sum(value::numeric) over (order by case key when 'common' then 1 when 'rare' then 2
                                                                 when 'epic' then 3 else 4 end) as cum
          from jsonb_each_text(c.odds)) s
       where cum > roll order by cum limit 1;
    end if;
    -- only items from ventures the player has reached
    select * into item from collectibles
     where theme = c.theme and rarity = rar and unlock_tier <= g.rank_tier
     order by random() limit 1;
    if item.id is null then
      select * into item from collectibles where theme = c.theme and rarity = 'common' and unlock_tier <= g.rank_tier
       order by random() limit 1;
    end if;
    if item.id is not null then
      insert into child_collection (game_id, child_id, collectible_id) values (p_game, g.child_id, item.id)
      on conflict (game_id, collectible_id) do update set quantity = child_collection.quantity + 1;
      got := got || jsonb_build_object('id', item.id, 'name', item.name, 'rarity', item.rarity,
                                       'kind', item.kind, 'slot', item.slot, 'image_url', item.image_url,
                                       'story', item.story, 'unlock_tier', item.unlock_tier);
      if item.rarity in ('epic', 'legendary') then got_epic := true; end if;
      if item.rarity = 'legendary' then got_leg := true; end if;
    end if;
  end loop;

  pity_epic := case when got_epic then 0 else g.crates_since_epic + 1 end;
  pity_leg := case when got_leg then 0 else g.crates_since_legendary + 1 end;
  update child_games set crates_since_epic = pity_epic, crates_since_legendary = pity_leg where id = p_game;
  insert into crate_openings (child_id, game_id, crate_id, cost, items) values (g.child_id, p_game, c.id, c.price, got);
  return jsonb_build_object('items', got, 'credits', g.credits - c.price,
                            'epic_in', 10 - pity_epic, 'legendary_in', 40 - pity_leg);
end $function$
;
CREATE OR REPLACE FUNCTION public.owns_child(c uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from children where id = c and parent_id = auth.uid());
$function$
;
CREATE OR REPLACE FUNCTION public.owns_game(g uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from child_games cg join children c on c.id = cg.child_id
                  where cg.id = g and c.parent_id = (select auth.uid()));
$function$
;
CREATE OR REPLACE FUNCTION public.rank_info(p_game uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'tier', g.rank_tier, 'level', g.rank_level,
    'tier_name', coalesce(t.tier_names[g.rank_tier], 'Tier ' || g.rank_tier),
    'next_tier_name', t.tier_names[g.rank_tier + 1],
    'level_progress', g.rank_xp % 5, 'per_level', 5, 'levels_per_tier', 10,
    'max_tier', coalesce(array_length(t.tier_names, 1), 1))
  from child_games g join themes t on t.id = g.theme where g.id = p_game;
$function$
;
CREATE OR REPLACE FUNCTION public.request_account_deletion(p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r account_deletion_requests;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select * into r from account_deletion_requests where user_id = auth.uid() and cancelled_at is null and done_at is null;
  if r.id is null then
    insert into account_deletion_requests (user_id, email, reason)
    values (auth.uid(), (select email from auth.users where id = auth.uid()), nullif(trim(p_reason), ''))
    returning * into r;
  end if;
  return jsonb_build_object('id', r.id, 'requested_at', r.requested_at, 'delete_by', r.requested_at + interval '30 days');
end $function$
;
CREATE OR REPLACE FUNCTION public.review_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_reviewer() then raise exception 'Reviewers only'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', q.id, 'topic', q.topic, 'difficulty', q.difficulty, 'calculator', q.calculator, 'version', q.version,
      'spec_point', q.spec_point,
      'wording', coalesce((select wording from theme_wording w where w.template_id = q.id and w.theme = 'generic'), q.spec_point),
      'tip', q.template->'tip', 'steps', q.template->'steps', 'explain', q.template->'explain',
      'refs', (select jsonb_object_agg(board, spec_ref) from template_spec_refs r where r.template_id = q.id),
      'counts', (select jsonb_build_object(
          'approved', count(*) filter (where status = 'approved'),
          'unchecked', count(*) filter (where status = 'unchecked'),
          'rejected', count(*) filter (where status = 'rejected'))
        from question_variants v where v.template_id = q.id and v.template_version = q.version),
      'last_review', (select jsonb_build_object('verdict', r.verdict, 'note', r.note, 'at', r.created_at,
          'by', coalesce((select name from tutors t where t.id = r.reviewer), 'Admin'))
        from template_reviews r where r.template_id = q.id order by r.created_at desc limit 1),
      'samples', (select jsonb_agg(jsonb_build_object('id', s.id, 'vars', s.vars, 'answer', s.answer_text, 'status', s.status))
        from (select * from question_variants v where v.template_id = q.id and v.template_version = q.version
              and v.status <> 'rejected' order by (v.status = 'unchecked') desc, md5(v.id::text) limit 4) s)
    ) order by q.topic, q.id)
    from question_templates q where q.status is distinct from 'retired' and q.tier = 'Foundation'
  ), '[]'::jsonb);
end $function$
;
CREATE OR REPLACE FUNCTION public.review_template(p_template text, p_verdict text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_tpl question_templates; v_n int := 0; v_tutor uuid;
begin
  if not public.is_reviewer() then raise exception 'Reviewers only'; end if;
  select * into v_tpl from question_templates where id = p_template;
  if v_tpl.id is null then raise exception 'Unknown question'; end if;
  if p_verdict not in ('approved','needs_changes') then raise exception 'Choose approve or needs changes'; end if;
  if p_verdict = 'needs_changes' and coalesce(trim(p_note),'') = '' then raise exception 'Add a note saying what needs changing'; end if;
  select id into v_tutor from tutors where id = auth.uid();
  insert into template_reviews (template_id, template_version, reviewer, verdict, note)
  values (v_tpl.id, v_tpl.version, auth.uid(), p_verdict, nullif(trim(p_note),''));
  if p_verdict = 'approved' then
    update question_variants set status = 'approved', checked_by = v_tutor, checked_at = now()
     where template_id = v_tpl.id and template_version = v_tpl.version and status = 'unchecked';
    get diagnostics v_n = row_count;
  end if;
  return jsonb_build_object('template', v_tpl.id, 'verdict', p_verdict, 'variants_approved', v_n);
end $function$
;
CREATE OR REPLACE FUNCTION public.review_variant(p_variant bigint, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_tutor uuid; v_row question_variants;
begin
  if not public.is_reviewer() then raise exception 'Reviewers only'; end if;
  if p_status not in ('approved','rejected','unchecked') then raise exception 'Bad status'; end if;
  select id into v_tutor from tutors where id = auth.uid();
  update question_variants set status = p_status, checked_by = case when p_status = 'unchecked' then null else v_tutor end,
         checked_at = case when p_status = 'unchecked' then null else now() end
   where id = p_variant returning * into v_row;
  if v_row.id is null then raise exception 'Unknown number set'; end if;
  return jsonb_build_object('id', v_row.id, 'status', v_row.status);
end $function$
;
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.set_child_pin(p_child uuid, p_pin text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.owns_child(p_child) then raise exception 'Not your child'; end if;
  if p_pin !~ '^[0-9]{4}$' then raise exception 'PIN must be 4 digits'; end if;
  insert into child_pins (child_id, pin_hash) values (p_child, crypt(p_pin, gen_salt('bf')))
  on conflict (child_id) do update set pin_hash = excluded.pin_hash;
end $function$
;
CREATE OR REPLACE FUNCTION public.set_focus_topics(p_child uuid, p_topics text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;
CREATE OR REPLACE FUNCTION public.set_lineup(p_game uuid, p_items text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare wanted text[] := array(select distinct x from unnest(coalesce(p_items, '{}')) x);
begin
  if not public.owns_game(p_game) then raise exception 'Game not found'; end if;
  if cardinality(wanted) > 5 then raise exception 'Pick up to 5 players'; end if;
  if exists (select 1 from matches where game_id = p_game and status = 'live') then raise exception 'Finish your match first'; end if;
  if (select count(*) from child_collection where game_id = p_game and collectible_id = any(wanted)) <> cardinality(wanted) then
    raise exception 'You do not have that player';
  end if;
  update child_collection set in_lineup = (collectible_id = any(wanted)) where game_id = p_game;
  update child_collection set equipped_slot = null where game_id = p_game and equipped_slot = 'captain' and not in_lineup;
  return public.league_info(p_game);
end $function$
;
CREATE OR REPLACE FUNCTION public.sim_goals(p_for integer, p_against integer)
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  select count(*)::int from generate_series(1, 5)
   where random() < least(greatest(0.25 + 0.03 * (p_for - p_against), 0.08), 0.6);
$function$
;
CREATE OR REPLACE FUNCTION public.start_check(p_child uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;
CREATE OR REPLACE FUNCTION public.start_match(p_game uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g child_games; m matches; played int; opp league_teams;
begin
  select * into g from child_games where id = p_game for update;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  select * into m from matches where game_id = p_game and status = 'live';
  if m.id is not null then return public.match_json(m.id); end if;
  perform public.ensure_team(p_game);
  select count(distinct round) into played from league_results where game_id = p_game and season = g.season and tier = g.rank_tier;
  if played >= 7 then
    update child_games set season = season + 1 where id = p_game returning * into g;
    played := 0;
  end if;
  opp := public.league_team_at(g.theme, g.rank_tier, ((6 + played) % 7) + 1);
  insert into matches (game_id, season, tier, round, opponent_id, our_rating)
  values (p_game, g.season, g.rank_tier, played, opp.id, public.team_rating(p_game))
  returning * into m;
  return public.match_json(m.id);
end $function$
;
CREATE OR REPLACE FUNCTION public.submit_answer(p_attempt bigint, p_given text, p_shown_text text DEFAULT NULL::text, p_exam_mode boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a answers;
  v question_variants;
  t question_templates;
  g child_games;
  max_tier int;
  given_norm text;
  given_num numeric;
  ok boolean := false;
  secs numeric;
  bonus int := 0;
  award int := 0;
  old_box int;
  new_box int;
  due timestamptz;
  new_xp int;
  new_level int;
  new_tier int;
  levelled boolean := false;
  tiered boolean := false;
begin
  select * into a from answers where id = p_attempt for update;
  if a.id is null or a.game_id is null or not public.owns_child(a.child_id) then raise exception 'Question not found'; end if;
  if a.answered_at is not null then raise exception 'Already answered'; end if;
  select * into v from question_variants where id = a.variant_id;
  select * into t from question_templates where id = a.template_id;

  given_num := public.answer_as_number(p_given);
  ok := coalesce(public.answer_is_correct(a.variant_id, p_given), false);

  secs := extract(epoch from now() - a.served_at);
  if ok and secs >= 2 then
    bonus := (public.game_perks(a.game_id) ->> 'coin_bonus')::int;
    award := 10 + bonus + case when p_exam_mode then 2 else 0 end;
  end if;

  update answers set answered_at = now(), given_text = left(p_given, 200), given_answer = given_num,
         correct = ok, shown_text = left(p_shown_text, 2000), exam_mode = coalesce(p_exam_mode, false),
         credits_awarded = award
   where id = p_attempt;

  -- coins and rank
  select * into g from child_games where id = a.game_id for update;
  select coalesce(array_length(tier_names, 1), 1) into max_tier from themes where id = g.theme;
  new_xp := g.rank_xp; new_level := g.rank_level; new_tier := g.rank_tier;
  if ok and secs >= 2 and not (g.rank_tier >= max_tier and g.rank_level >= 10) then
    new_xp := g.rank_xp + 1;
    if new_xp % 5 = 0 then
      levelled := true;
      if g.rank_level >= 10 then
        if g.rank_tier < max_tier and not exists (select 1 from themes where id = g.theme and has_league) then new_tier := g.rank_tier + 1; new_level := 1; tiered := true; end if;
      else
        new_level := g.rank_level + 1;
      end if;
    end if;
  end if;
  levelled := levelled and (new_level <> g.rank_level or new_tier <> g.rank_tier);
  update child_games set credits = credits + award, rank_xp = new_xp, rank_level = new_level, rank_tier = new_tier
   where id = a.game_id;

  -- spaced repetition
  select box into old_box from child_mastery
   where child_id = a.child_id and template_id = a.template_id for update;
  if ok then
    new_box := least(greatest(coalesce(old_box, 0), 1) + 1, 4);
    due := now() + case new_box when 2 then interval '2 days' when 3 then interval '7 days' else interval '21 days' end;
  else
    new_box := 1;
    due := now() + interval '2 minutes';
  end if;
  insert into child_mastery (child_id, template_id, box, times_seen, times_correct, next_review_at, last_seen_at)
  values (a.child_id, a.template_id, new_box, 1, case when ok then 1 else 0 end, due, now())
  on conflict (child_id, template_id) do update
    set box = excluded.box, times_seen = child_mastery.times_seen + 1,
        times_correct = child_mastery.times_correct + excluded.times_correct,
        next_review_at = excluded.next_review_at, last_seen_at = now();

  return jsonb_build_object(
    'correct', ok, 'answer', coalesce(v.answer_text, v.answer::text), 'steps', t.template -> 'steps', 'explain', t.template -> 'explain', 'vars', v.vars,
    'credits_awarded', award, 'gear_bonus', bonus, 'credits', g.credits + award,
    'too_fast', ok and secs < 2, 'levelled_up', levelled, 'tier_up', tiered,
    'rank', public.rank_info(a.game_id));
end $function$
;
CREATE OR REPLACE FUNCTION public.submit_check_answer(p_attempt bigint, p_given text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;
CREATE OR REPLACE FUNCTION public.team_rating(p_game uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(case c.rarity when 'rare' then 2 when 'epic' then 3 when 'legendary' then 4 else 1 end), 0)::int
    from child_collection cc join collectibles c on c.id = cc.collectible_id
   where cc.game_id = p_game and cc.in_lineup;
$function$
;
CREATE OR REPLACE FUNCTION public.unequip_slot(p_game uuid, p_slot text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.owns_game(p_game) then raise exception 'Game not found'; end if;
  update child_collection set equipped_slot = null where game_id = p_game and equipped_slot = p_slot;
end $function$
;

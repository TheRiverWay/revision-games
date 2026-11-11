-- Football Manager Maths: five-a-side team, match day and a league.
-- Themes with has_league promote through league finishes instead of the answer-count rank.

alter table themes add column if not exists has_league boolean not null default false;
update themes set has_league = true where id = 'football';
alter table child_collection add column if not exists in_lineup boolean not null default false;
alter table child_games add column if not exists season int not null default 1;
alter table answers add column if not exists match_id bigint;

create table if not exists league_teams (
  id serial primary key,
  theme text not null references themes(id),
  tier int not null,
  name text not null,
  rating int not null
);
alter table league_teams enable row level security;

create table if not exists matches (
  id bigserial primary key,
  game_id uuid not null references child_games(id) on delete cascade,
  season int not null,
  tier int not null,
  round int not null,                 -- 0..6
  opponent_id int not null references league_teams(id),
  our_rating int not null,
  status text not null default 'live',
  our_goals int not null default 0,
  their_goals int not null default 0,
  events jsonb not null default '[]',
  credits_awarded int not null default 0,
  season_end jsonb,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
alter table matches enable row level security;
create unique index if not exists matches_one_live on matches (game_id) where status = 'live';

-- Every result in a child's league. Team 0 is the child's club, 1..7 are league_teams in id order.
create table if not exists league_results (
  game_id uuid not null references child_games(id) on delete cascade,
  season int not null, tier int not null, round int not null,
  home int not null, away int not null, home_goals int not null, away_goals int not null
);
alter table league_results enable row level security;
create index if not exists league_results_lookup on league_results (game_id, season, tier);

-- Made-up teams, 7 per division. Ratings sit on the same 5..20 scale as a five of commons..legendaries.
insert into league_teams (theme, tier, name, rating)
select 'football', t.tier, t.name, t.rating from (values
  (1,'Red Lion Rovers',3),(1,'Kings Arms Athletic',4),(1,'Parkside Wanderers',4),(1,'Old Boys United',5),(1,'Dog & Duck FC',6),(1,'Allotment Albion',6),(1,'Car Park Rangers',7),
  (2,'Millbrook Town',6),(2,'Ashcombe Vale',7),(2,'Harbour Athletic',7),(2,'Stoneleigh Borough',8),(2,'Fenwick Rovers',9),(2,'Kestrel FC',9),(2,'Lowmoor Town',10),
  (3,'Castlebridge City',9),(3,'Northgate United',10),(3,'Westholm Athletic',10),(3,'Ravenscourt Town',11),(3,'Dunmore Rovers',12),(3,'Halbury Albion',12),(3,'Crestwood FC',13),
  (4,'Port Ellis',12),(4,'Brackenridge Wanderers',13),(4,'Ironvale United',13),(4,'Seacombe City',14),(4,'Thornfield Athletic',15),(4,'Highmarsh Rovers',15),(4,'Kingsgate Town',16),
  (5,'Redcliffe Rovers',15),(5,'Eastmoor City',16),(5,'Granmere Park',16),(5,'Silverton United',17),(5,'Blackwater Athletic',18),(5,'Oakhurst Albion',18),(5,'Larkwood Forest',19),
  (6,'Northbridge City',17),(6,'Royal Southport',18),(6,'Atlas Athletic',18),(6,'Kingstown United',19),(6,'Ravenhall Rovers',19),(6,'Crown City',20),(6,'Meridian FC',20)
) t(tier, name, rating)
where not exists (select 1 from league_teams where theme = 'football');

-- ---------- helpers (not callable by the app) ----------
create or replace function public.team_rating(p_game uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(case c.rarity when 'rare' then 2 when 'epic' then 3 when 'legendary' then 4 else 1 end), 0)::int
    from child_collection cc join collectibles c on c.id = cc.collectible_id
   where cc.game_id = p_game and cc.in_lineup;
$$;

-- Round robin for 8 teams (circle method). Round 0..6. Team 0 always plays a[8].
create or replace function public.league_fixtures(p_round int) returns table(home int, away int)
language sql immutable set search_path = public as $$
  with arr as (select array[0] || array(select ((k - 1 + p_round) % 7) + 1 from generate_series(1, 7) k) a)
  select a[i + 1], a[8 - i] from arr, generate_series(0, 3) i;
$$;

create or replace function public.league_team_at(p_theme text, p_tier int, p_idx int) returns league_teams
language sql stable set search_path = public as $$
  select * from league_teams where theme = p_theme and tier = p_tier order by id offset p_idx - 1 limit 1;
$$;

create or replace function public.sim_goals(p_for int, p_against int) returns int
language sql volatile set search_path = public as $$
  select count(*)::int from generate_series(1, 5)
   where random() < least(greatest(0.25 + 0.03 * (p_for - p_against), 0.08), 0.6);
$$;

create or replace function public.league_table(p_game uuid, p_season int, p_tier int) returns jsonb
language sql stable security definer set search_path = public as $$
  with g as (select * from child_games where id = p_game),
  teams as (
    select 0 as idx, coalesce(nullif(g.custom_names ->> 'team', ''), 'Your club') as name, true as me from g
    union all
    select (row_number() over (order by lt.id))::int, lt.name, false
      from league_teams lt, g where lt.theme = g.theme and lt.tier = p_tier),
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
$$;

create or replace function public.match_json(p_match bigint) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', m.id, 'round', m.round + 1, 'rounds', 7, 'status', m.status,
    'our_goals', m.our_goals, 'their_goals', m.their_goals, 'events', m.events,
    'questions', 6, 'our_rating', m.our_rating,
    'opponent', lt.name, 'their_rating', lt.rating,
    'credits_awarded', m.credits_awarded, 'season_end', m.season_end)
  from matches m join league_teams lt on lt.id = m.opponent_id where m.id = p_match;
$$;

-- Season results, credits and promotion when the child's match ends.
create or replace function public.finish_match(p_match bigint) returns void
language plpgsql security definer set search_path = public as $$
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
end $$;

-- ---------- callable by the app ----------

-- New clubs get five academy players; a club with players but no five gets its best five picked.
create or replace function public.ensure_team(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
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
end $$;

create or replace function public.set_lineup(p_game uuid, p_items text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
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
end $$;

create or replace function public.league_info(p_game uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare g child_games; th themes; played int; live bigint; last_m bigint;
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
end $$;

create or replace function public.start_match(p_game uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
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
end $$;

-- One answered question = one chance in the match.
create or replace function public.match_event(p_match bigint, p_attempt bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
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
  if a.id is null or a.game_id <> m.game_id or a.answered_at is null or a.match_id is not null or a.served_at < m.created_at then
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
end $$;

-- League themes stop the answer-count rank from promoting; the league does it instead.
do $$
declare d text; n text;
begin
  select pg_get_functiondef('public.submit_answer(bigint,text,text,boolean)'::regprocedure) into d;
  n := replace(d, 'if g.rank_tier < max_tier then new_tier',
                  'if g.rank_tier < max_tier and not exists (select 1 from themes where id = g.theme and has_league) then new_tier');
  n := replace(n, '  update child_games set credits = credits + award, rank_xp',
                  '  levelled := levelled and (new_level <> g.rank_level or new_tier <> g.rank_tier);
  update child_games set credits = credits + award, rank_xp');
  if n = d or position('has_league' in n) = 0 or position('levelled := levelled and' in n) = 0 then
    raise exception 'submit_answer patch points not found';
  end if;
  execute n;
end $$;

revoke execute on function public.team_rating(uuid), public.league_fixtures(int), public.league_team_at(text, int, int),
  public.sim_goals(int, int), public.league_table(uuid, int, int), public.match_json(bigint), public.finish_match(bigint)
  from public, anon, authenticated;
revoke execute on function public.ensure_team(uuid), public.set_lineup(uuid, text[]), public.league_info(uuid),
  public.start_match(uuid), public.match_event(bigint, bigint) from public, anon;
grant execute on function public.ensure_team(uuid), public.set_lineup(uuid, text[]), public.league_info(uuid),
  public.start_match(uuid), public.match_event(bigint, bigint) to authenticated;

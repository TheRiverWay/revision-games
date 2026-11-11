-- Field Command (military skin): wording, collectibles and crate. Run 2026-11-09 against "Revision Games".
-- Missions, rescue, engineering and logistics only: no combat, weapons, real armies, insignia or brands.
-- {squad} and {callsign} come from the kid's custom_names. Units match each template's worked explanation.
-- Theme row already existed and stays status 'draft'. Statements below are in the order they were run.
-- Read-only exploration queries (reading templates, wording, themes and function source) are not repeated here.

-- 1. Question wording, one per template
insert into theme_wording (template_id, theme, wording) values
('ALG-01','military',$q${squad}'s mission score is S = 3W + D, where W is winch rescues and D is supply drops. Find S when W = {W} and D = {D}.$q$),
('ALG-02','military',$q${squad} carried {b} sandbags in trips of {a} bags each. How many trips? Solve {a}x = {b}.$q$),
('ALG-03','military',$q$Engineers lay {a} m of track per hour, plus {b} m done before breakfast. That's {c} m in total. How many hours?$q$),
('ALG-04','military',$q$Flood water at the rescue camp, in cm above the marker, on days 1 to 4: {terms}. Find the nth term.$q$),
('ANG-01','military',$q$A rescue ramp meets the flat ground at {A}°. What is the angle on the other side?$q$),
('ANG-02','military',$q$A triangular tent at {squad}'s camp has angles {A}° and {B}°. Find the third angle.$q$),
('ANG-03','military',$q$Four guy ropes spread round a tent pole at angles {A}°, {B}°, {C}° and x. Find x.$q$),
('ARE-01','military',$q${squad}'s new base is {L} m by {W} m. How much fencing goes all the way round?$q$),
('ARE-02','military',$q$A helicopter landing field is {L} m by {W} m. What is its area in m²?$q$),
('ARE-03','military',$q$A triangular shelter tarp has base {B} m and height {H} m. What is its area?$q$),
('ARE-04','military',$q$A circular helipad has radius {R} m. What is its area, to 1 decimal place?$q$),
('AVG-01','military',$q$Rescues made by {squad} on each shift: {list}. What is the mean number of rescues per shift?$q$),
('AVG-02','military',$q$Recruits' tent-building scores out of 10: {list}. What is the median score?$q$),
('AVG-03','military',$q$Supply crates delivered to base each day: {list}. Find the mode and the range.$q$),
('AVG-04','military',$q${squad} averages {M} rescues a day over {N} days. Here are {Nm1} of them: {list}. How many rescues on the last day?$q$),
('CMP-01','military',$q${callsign}'s search dog runs {D} m in {T} seconds. What is its speed in m/s?$q$),
('CMP-02','military',$q$The supply truck drives at {S} km/h for {T} hours to reach the field hospital. How far is it?$q$),
('CMP-03','military',$q$The flood camp is {D} km away and the convoy averages {S} km/h. How long is the journey?$q$),
('CMP-04','military',$q${squad} spends £{C} on {Q} kg of rice for the relief camp. What is the cost per kg?$q$),
('DEC-01','military',$q$The quartermaster buys a £{A} tent and a £{B} lantern, then uses a £{C} voucher. What do they pay?$q$),
('DEC-02','military',$q$Each first aid kit costs £{A}. The field hospital orders {N}. What is the total?$q$),
('DEC-03','military',$q$Deal 1: {N1} rolls of bandage for £{P1}. Deal 2: {N2} rolls of bandage for £{P2}. Which deal is better value?$q$),
('DEC-04','military',$q${callsign} hikes {X} km on a navigation exercise. Round it to {DP} decimal places.$q$),
('FRA-01','military',$q${N}/{D} of {squad}'s £{A} supply budget goes on fuel. How much is that?$q$),
('FRA-02','military',$q${N} of the {D} recruits passed the knot test. Write this as a fraction in its simplest form.$q$),
('FRA-03','military',$q${callsign} spends {N1}/{D1} of an hour checking radios, then {N2}/{D2} of an hour packing kit. What fraction of an hour is that?$q$),
('FRA-04','military',$q${N}/{D} of the camp's water tanks are full. What is that as a percentage?$q$),
('NUM-01','military',$q$It's {A}°C at the mountain base camp. Overnight it drops by {B}°C. What temperature is it now?$q$),
('NUM-02','military',$q$Mission points = 3 × rescues + supply drops. {squad} has {W} rescues and {D} supply drops. How many mission points?$q$),
('NUM-03','military',$q$Two radio beacons beep every {A} and {B} minutes. They just beeped together. After how many minutes do they next beep together?$q$),
('NUM-04','military',$q$The relief camp handed out {X} bottles of water this year. Round it to the nearest {to}.$q$),
('PCT-01','military',$q${B}% of the £{A} raised for the field hospital buys bandages. How much is that?$q$),
('PCT-02','military',$q$The base's £{A} weekly fuel bill rises by {B}%. What is the new bill?$q$),
('PCT-03','military',$q$A £{A} sleeping bag is cut by {B}% in the camp shop sale. What is the new price?$q$),
('PCT-04','military',$q${squad} found {A} of the {B} hidden map markers. What percentage is that?$q$),
('PRO-01','military',$q$A kit bag holds {T} ration packs and {A} are chocolate flavour. What is the probability of picking chocolate?$q$),
('PRO-02','military',$q$The probability the radio picks up a signal is {P}. What is the probability it doesn't?$q$),
('PRO-03','military',$q$The probability a supply drop lands on target is {P}. How many of the next {N} drops do you expect to land on target?$q$),
('PRO-04','military',$q$The search dog found the scent in {A} of {N} drills. Estimate the probability it finds it next time.$q$),
('PYT-01','military',$q$A map board in {squad}'s command tent is {A} cm by {B} cm. How long is its diagonal?$q$),
('PYT-02','military',$q$A map board's diagonal is {C} cm and its height is {A} cm. How wide is it?$q$),
('RAT-01','military',$q${squad} packed {A} water bottles and {B} ration packs. Write the ratio of bottles to packs in its simplest form.$q$),
('RAT-02','military',$q$£{T} of supplies is shared between the field hospital and the camp kitchen in the ratio {A}:{B}. How much does each get?$q$),
('RAT-03','military',$q$At the field hospital, medics to patients are in the ratio {A}:{B}. There are {X} medics on shift. How many patients can they care for?$q$),
('RAT-04','military',$q$Rescue flights to rescue drives are in the ratio {A}:{B}. What fraction of the rescues were flights?$q$),
('UNI-01','military',$q${callsign}'s search team walked {X} m along the river. How many km is that?$q$),
('UNI-02','military',$q${squad} starts a bridge-building drill at {start}. It lasts {mins} minutes. When does it finish?$q$),
('UNI-03','military',$q${squad} buys a tent repair kit from a supplier in Europe for €{A}. £1 = €{R}. What is that in pounds?$q$),
('VOL-01','military',$q${squad}'s ration box is {L} cm by {W} cm by {H} cm. What is its volume?$q$),
('VOL-02','military',$q$A water carrier at camp is a cylinder with radius {R} cm and height {H} cm. What is its volume, to 1 decimal place?$q$);

-- 2. Placeholder check (returned 0 rows): every {x} in a military row is used by that template's
--    generic/tycoon/football wording or is squad/callsign; no generic maths placeholder is missing; no template missing.
with ph as (
  select w.template_id, w.theme, m[1] as k
  from theme_wording w, regexp_matches(w.wording, '\{(\w+)\}', 'g') m
  where w.theme in ('generic','tycoon','football','military')
), allowed as (
  select distinct template_id, k from ph where theme in ('generic','tycoon','football')
  union select distinct template_id, unnest(array['squad','callsign']) from ph
), maths as (
  select distinct template_id, k from ph where theme = 'generic'
)
select 'unknown placeholder' as problem, p.template_id, p.k from ph p
 where p.theme='military' and not exists (select 1 from allowed a where a.template_id=p.template_id and a.k=p.k)
union all
select 'missing maths placeholder', m.template_id, m.k from maths m
 where not exists (select 1 from ph p where p.theme='military' and p.template_id=m.template_id and p.k=m.k)
union all
select 'missing row', t.id, null from question_templates t
 where not exists (select 1 from theme_wording w where w.template_id=t.id and w.theme='military')
order by 1,2,3;

-- 3. Every maths placeholder exists in every live variant's vars (returned 0 rows)
select w.template_id, m[1] k, count(*) filter (where not (v.vars ? m[1])) missing_in, count(*) variants
from theme_wording w cross join lateral regexp_matches(w.wording, '\{(\w+)\}', 'g') m
join question_templates t on t.id=w.template_id
join question_variants v on v.template_id=t.id and v.template_version=t.version and v.status<>'rejected'
where w.theme='military' and m[1] not in ('squad','callsign')
group by 1,2 having count(*) filter (where not (v.vars ? m[1]))>0;

-- 4. 100 collectibles: 60 gear (vehicle, radio, boots; coin_bonus 1-4 by rarity), 40 cosmetics (badge, camo, base).
-- Totals 50 common, 30 rare, 15 epic, 5 legendary. Camo has no legendary so the totals land exactly.
insert into collectibles (id, theme, name, rarity, kind, slot, perks) values
('MIL-001','military','Muddy Quad Bike','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-002','military','Squeaky Push Bike','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-003','military','Wonky Wheelbarrow','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-004','military','Rusty Supply Trailer','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-005','military','Dented Pickup','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-006','military','Patched-Up Dinghy','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-007','military','Old Farm Tractor','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-008','military','Bouncy Six-Wheeler','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-009','military','Creaky Canoe','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-010','military','Wobbly Motor Scooter','common','gear','vehicle','{"coin_bonus":1}'),
('MIL-011','military','Rescue Hovercraft','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-012','military','Snow Crawler','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-013','military','Amphibious Truck','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-014','military','Bridge-Laying Lorry','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-015','military','Mountain Rescue Truck','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-016','military','Swamp Airboat','rare','gear','vehicle','{"coin_bonus":2}'),
('MIL-017','military','Heavy-Lift Helicopter','epic','gear','vehicle','{"coin_bonus":3}'),
('MIL-018','military','Mobile Field Hospital','epic','gear','vehicle','{"coin_bonus":3}'),
('MIL-019','military','Arctic Icebreaker Ship','epic','gear','vehicle','{"coin_bonus":3}'),
('MIL-020','military','Sky Crane Airship','legendary','gear','vehicle','{"coin_bonus":4}'),
('MIL-021','military','Crackly Walkie-Talkie','common','gear','radio','{"coin_bonus":1}'),
('MIL-022','military','Tin Can Telephone','common','gear','radio','{"coin_bonus":1}'),
('MIL-023','military','Hand-Crank Radio','common','gear','radio','{"coin_bonus":1}'),
('MIL-024','military','Battered Field Phone','common','gear','radio','{"coin_bonus":1}'),
('MIL-025','military','Fuzzy Two-Way Radio','common','gear','radio','{"coin_bonus":1}'),
('MIL-026','military','Signal Whistle','common','gear','radio','{"coin_bonus":1}'),
('MIL-027','military','Morse Code Torch','common','gear','radio','{"coin_bonus":1}'),
('MIL-028','military','Semaphore Flag Set','common','gear','radio','{"coin_bonus":1}'),
('MIL-029','military','Pocket Pager','common','gear','radio','{"coin_bonus":1}'),
('MIL-030','military','Squawky Megaphone','common','gear','radio','{"coin_bonus":1}'),
('MIL-031','military','Long-Range Backpack Radio','rare','gear','radio','{"coin_bonus":2}'),
('MIL-032','military','Waterproof Handset','rare','gear','radio','{"coin_bonus":2}'),
('MIL-033','military','Solar Radio Kit','rare','gear','radio','{"coin_bonus":2}'),
('MIL-034','military','Satellite Phone','rare','gear','radio','{"coin_bonus":2}'),
('MIL-035','military','Hilltop Relay Mast','rare','gear','radio','{"coin_bonus":2}'),
('MIL-036','military','Rescue Beacon','rare','gear','radio','{"coin_bonus":2}'),
('MIL-037','military','Mobile Comms Tent','epic','gear','radio','{"coin_bonus":3}'),
('MIL-038','military','Drone Relay Station','epic','gear','radio','{"coin_bonus":3}'),
('MIL-039','military','Weather Radar Truck','epic','gear','radio','{"coin_bonus":3}'),
('MIL-040','military','Orbital Uplink Dish','legendary','gear','radio','{"coin_bonus":4}'),
('MIL-041','military','Soggy Wellies','common','gear','boots','{"coin_bonus":1}'),
('MIL-042','military','Hand-Me-Down Hikers','common','gear','boots','{"coin_bonus":1}'),
('MIL-043','military','Squelchy Trainers','common','gear','boots','{"coin_bonus":1}'),
('MIL-044','military','Patched Canvas Boots','common','gear','boots','{"coin_bonus":1}'),
('MIL-045','military','Plain Black Boots','common','gear','boots','{"coin_bonus":1}'),
('MIL-046','military','Muddy Work Boots','common','gear','boots','{"coin_bonus":1}'),
('MIL-047','military','Socks and Sandals','common','gear','boots','{"coin_bonus":1}'),
('MIL-048','military','Steel Toe-Cap Boots','common','gear','boots','{"coin_bonus":1}'),
('MIL-049','military','Wobbly Snowshoes','common','gear','boots','{"coin_bonus":1}'),
('MIL-050','military','Tangled-Lace Boots','common','gear','boots','{"coin_bonus":1}'),
('MIL-051','military','Waterproof Trek Boots','rare','gear','boots','{"coin_bonus":2}'),
('MIL-052','military','Ice Grip Boots','rare','gear','boots','{"coin_bonus":2}'),
('MIL-053','military','Desert Sand Boots','rare','gear','boots','{"coin_bonus":2}'),
('MIL-054','military','Jungle Trek Boots','rare','gear','boots','{"coin_bonus":2}'),
('MIL-055','military','Swamp Waders','rare','gear','boots','{"coin_bonus":2}'),
('MIL-056','military','Rock Climbing Boots','rare','gear','boots','{"coin_bonus":2}'),
('MIL-057','military','Cliff Rescue Crampons','epic','gear','boots','{"coin_bonus":3}'),
('MIL-058','military','Self-Drying Boots','epic','gear','boots','{"coin_bonus":3}'),
('MIL-059','military','Featherlight Marathon Boots','epic','gear','boots','{"coin_bonus":3}'),
('MIL-060','military','Golden Moon Boots','legendary','gear','boots','{"coin_bonus":4}'),
('MIL-061','military','First Aid Badge','common','cosmetic','badge','{}'),
('MIL-062','military','Knot Tying Badge','common','cosmetic','badge','{}'),
('MIL-063','military','Map Reading Badge','common','cosmetic','badge','{}'),
('MIL-064','military','Tent Pitching Badge','common','cosmetic','badge','{}'),
('MIL-065','military','Campfire Cook Badge','common','cosmetic','badge','{}'),
('MIL-066','military','Early Riser Badge','common','cosmetic','badge','{}'),
('MIL-067','military','Tidy Bunk Badge','common','cosmetic','badge','{}'),
('MIL-068','military','Bridge Builder Badge','rare','cosmetic','badge','{}'),
('MIL-069','military','Night Navigator Badge','rare','cosmetic','badge','{}'),
('MIL-070','military','Swift Water Rescue Badge','rare','cosmetic','badge','{}'),
('MIL-071','military','Radio Ace Badge','rare','cosmetic','badge','{}'),
('MIL-072','military','Mountain Rescue Star','epic','cosmetic','badge','{}'),
('MIL-073','military','Flood Hero Medal','epic','cosmetic','badge','{}'),
('MIL-074','military','Golden Compass Medal','legendary','cosmetic','badge','{}'),
('MIL-075','military','Woodland Leaf Camo','common','cosmetic','camo','{}'),
('MIL-076','military','Muddy Puddle Camo','common','cosmetic','camo','{}'),
('MIL-077','military','Desert Dune Camo','common','cosmetic','camo','{}'),
('MIL-078','military','Grey Rock Camo','common','cosmetic','camo','{}'),
('MIL-079','military','Long Grass Camo','common','cosmetic','camo','{}'),
('MIL-080','military','Autumn Leaves Camo','common','cosmetic','camo','{}'),
('MIL-081','military','Plain Olive Kit','common','cosmetic','camo','{}'),
('MIL-082','military','Arctic Snow Camo','rare','cosmetic','camo','{}'),
('MIL-083','military','Jungle Vine Camo','rare','cosmetic','camo','{}'),
('MIL-084','military','Night Sky Camo','rare','cosmetic','camo','{}'),
('MIL-085','military','Moorland Heather Camo','rare','cosmetic','camo','{}'),
('MIL-086','military','Glow-in-the-Dark Camo','epic','cosmetic','camo','{}'),
('MIL-087','military','Rainbow Coral Camo','epic','cosmetic','camo','{}'),
('MIL-088','military','Leaky Pup Tent','common','cosmetic','base','{}'),
('MIL-089','military','Muddy Field Camp','common','cosmetic','base','{}'),
('MIL-090','military','Tarp and Stick Shelter','common','cosmetic','base','{}'),
('MIL-091','military','Garden Shed HQ','common','cosmetic','base','{}'),
('MIL-092','military','Cardboard Box Fort','common','cosmetic','base','{}'),
('MIL-093','military','Riverside Bivvy','common','cosmetic','base','{}'),
('MIL-094','military','Treehouse Outpost','rare','cosmetic','base','{}'),
('MIL-095','military','Mountain Hut','rare','cosmetic','base','{}'),
('MIL-096','military','Beach Rescue Station','rare','cosmetic','base','{}'),
('MIL-097','military','Big Top Mess Tent','rare','cosmetic','base','{}'),
('MIL-098','military','Lighthouse Lookout','epic','cosmetic','base','{}'),
('MIL-099','military','Floating River Base','epic','cosmetic','base','{}'),
('MIL-100','military','Secret Mountain HQ','legendary','cosmetic','base','{}');

-- 5. Crate
insert into crates (id, theme, name, price, items_per_crate, odds, active)
values ('military-crate','military','Supply Drop',100,3,'{"common":70,"rare":20,"epic":8,"legendary":2}',true);

-- 6. Distribution check: 50 common, 30 rare, 15 epic, 5 legendary; 60 gear, 40 cosmetic
select rarity, kind, count(*) from collectibles where theme='military' group by rollup(rarity, kind) order by 1,2;

-- 7. End-to-end test, rolled back by the final raise (nothing persists)
do $$
declare
  v_parent uuid := (select id from parents limit 1);
  v_child uuid; v_game uuid; q jsonb; ans text; sub jsonb; crate jsonb; gear text; perks jsonb; w text; shown text; k text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_parent, 'role','authenticated')::text, true);
  select id into v_child from children where parent_id = v_parent order by created_at limit 1;
  insert into child_games (child_id, subject, theme, custom_names)
  values (v_child, 'maths', 'military', '{"squad":"Test Squad","callsign":"Echo"}') returning id into v_game;

  q := next_question(v_game);
  select wording into w from theme_wording where template_id = q->>'template_id' and theme = 'military';
  shown := w;
  for k in select jsonb_object_keys(q->'vars') loop
    shown := replace(shown, '{'||k||'}', case jsonb_typeof(q->'vars'->k) when 'array' then (select string_agg(x, ', ') from jsonb_array_elements_text(q->'vars'->k) x) else q->'vars'->>k end);
  end loop;
  shown := replace(replace(shown, '{squad}', 'Test Squad'), '{callsign}', 'Echo');

  update answers set served_at = now() - interval '5 seconds' where id = (q->>'attempt_id')::bigint;
  ans := dev_answer((q->>'attempt_id')::bigint);
  sub := submit_answer((q->>'attempt_id')::bigint, ans, shown, false);

  update child_games set credits = 500 where id = v_game;
  crate := open_crate(v_game, 'military-crate');
  select cc.collectible_id into gear from child_collection cc join collectibles c on c.id = cc.collectible_id
   where cc.game_id = v_game and c.kind = 'gear' order by c.perks->>'coin_bonus' desc limit 1;
  if gear is null then
    insert into child_collection (game_id, child_id, collectible_id) values (v_game, v_child, 'MIL-020'); gear := 'MIL-020';
  end if;
  perform equip_item(v_game, gear);
  perks := game_perks(v_game);

  raise exception 'RESULTS q=% | shown=% | answer=% | submit correct=% awarded=% credits=% | crate=% | equipped=% | perks=% | credits_after=%',
    q->>'template_id', shown, ans, sub->>'correct', sub->>'credits_awarded', sub->>'credits',
    crate, gear, perks, (select credits from child_games where id = v_game);
end $$;
-- Result: RESULTS q=UNI-01 | shown=Echo's search team walked 8200 m along the river. How many km is that? | answer=8.2
--   | submit correct=true awarded=10 credits=10 | crate: Tarp and Stick Shelter, Fuzzy Two-Way Radio, Rusty Supply Trailer (all common), credits 400
--   | equipped=MIL-025 | perks={"coin_bonus": 1, "free_hints": 0, "streak_shields": 0} | credits_after=400

-- 8. Nothing persisted, theme still draft (returned games_left 0, status draft)
select (select count(*) from child_games where theme='military') games_left, (select status from themes where id='military') status;

-- 9. Sample render source: one random live variant per template
select distinct on (w.template_id) w.template_id, w.wording, v.vars, v.answer_text from theme_wording w
join question_templates t on t.id=w.template_id
join question_variants v on v.template_id=t.id and v.template_version=t.version and v.status<>'rejected'
where w.theme='military' order by w.template_id, random();

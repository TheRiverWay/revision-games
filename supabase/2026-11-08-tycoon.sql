-- Kitchen Tycoon (restaurant skin) on the shared tycoon wording.

-- Schema (already applied 2026-11-08 as migrations theme_word_packs_and_flavours and flavour_unlock_tier):
--   themes.wording_theme  borrow question wording from another theme (all tycoon skins use 'tycoon')
--   themes.default_words  words for {placeholders}; theme_flavours.words override them; kid's custom_names override both
--   theme_flavours        ventures/cuisines per theme, unlock_tier = rank tier where the kid can pick it
--   child_games.flavour   the kid's current venture

-- 100 cuisine-neutral collectibles: an epic oven works in a taco stall and in fine dining.
-- Gear (oven, fryer, delivery) adds cash per right answer by rarity. Cosmetics are just for show.
insert into collectibles (id, theme, name, rarity, kind, slot, perks) values

('RST-001','restaurant','Rusty Camping Stove','common','gear','oven','{"coin_bonus":1}'),
('RST-002','restaurant','Wobbly Hotplate','common','gear','oven','{"coin_bonus":1}'),
('RST-003','restaurant','Second-Hand Oven','common','gear','oven','{"coin_bonus":1}'),
('RST-004','restaurant','Little Toaster Oven','common','gear','oven','{"coin_bonus":1}'),
('RST-005','restaurant','Single Gas Ring','common','gear','oven','{"coin_bonus":1}'),
('RST-006','restaurant','Old Range Cooker','common','gear','oven','{"coin_bonus":1}'),
('RST-007','restaurant','Budget Oven','common','gear','oven','{"coin_bonus":1}'),
('RST-008','restaurant','Basic Griddle','common','gear','oven','{"coin_bonus":1}'),
('RST-009','restaurant','Countertop Oven','common','gear','oven','{"coin_bonus":1}'),
('RST-010','restaurant','Hand-Me-Down Hob','common','gear','oven','{"coin_bonus":1}'),
('RST-011','restaurant','Steel Convection Oven','rare','gear','oven','{"coin_bonus":2}'),
('RST-012','restaurant','Twin Deck Oven','rare','gear','oven','{"coin_bonus":2}'),
('RST-013','restaurant','Stone Hearth Oven','rare','gear','oven','{"coin_bonus":2}'),
('RST-014','restaurant','Turbo Griddle','rare','gear','oven','{"coin_bonus":2}'),
('RST-015','restaurant','Combi Steam Oven','rare','gear','oven','{"coin_bonus":2}'),
('RST-016','restaurant','Charcoal Grill','rare','gear','oven','{"coin_bonus":2}'),
('RST-017','restaurant','Wood-Fired Dome Oven','epic','gear','oven','{"coin_bonus":3}'),
('RST-018','restaurant','Chef''s Copper Range','epic','gear','oven','{"coin_bonus":3}'),
('RST-019','restaurant','Inferno Grill','epic','gear','oven','{"coin_bonus":3}'),
('RST-020','restaurant','The Dragon''s Breath Oven','legendary','gear','oven','{"coin_bonus":4}'),
('RST-021','restaurant','Splattery Chip Pan','common','gear','fryer','{"coin_bonus":1}'),
('RST-022','restaurant','Mini Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-023','restaurant','Basket Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-024','restaurant','Tabletop Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-025','restaurant','Little Air Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-026','restaurant','Single Basket Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-027','restaurant','Dented Deep Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-028','restaurant','Starter Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-029','restaurant','Hand-Me-Down Fryer','common','gear','fryer','{"coin_bonus":1}'),
('RST-030','restaurant','Wobbly Wok','common','gear','fryer','{"coin_bonus":1}'),
('RST-031','restaurant','Double Basket Fryer','rare','gear','fryer','{"coin_bonus":2}'),
('RST-032','restaurant','Stainless Steel Fryer','rare','gear','fryer','{"coin_bonus":2}'),
('RST-033','restaurant','Crispmaster 3000','rare','gear','fryer','{"coin_bonus":2}'),
('RST-034','restaurant','Turbo Air Fryer','rare','gear','fryer','{"coin_bonus":2}'),
('RST-035','restaurant','Twin Tank Fryer','rare','gear','fryer','{"coin_bonus":2}'),
('RST-036','restaurant','Speedy Fryer','rare','gear','fryer','{"coin_bonus":2}'),
('RST-037','restaurant','Golden Crunch Fryer','epic','gear','fryer','{"coin_bonus":3}'),
('RST-038','restaurant','Triple Tank Fryer','epic','gear','fryer','{"coin_bonus":3}'),
('RST-039','restaurant','Thunder Fryer','epic','gear','fryer','{"coin_bonus":3}'),
('RST-040','restaurant','The Everlasting Crisp','legendary','gear','fryer','{"coin_bonus":4}'),
('RST-041','restaurant','Old Bicycle','common','gear','delivery','{"coin_bonus":1}'),
('RST-042','restaurant','Wonky Scooter','common','gear','delivery','{"coin_bonus":1}'),
('RST-043','restaurant','Squeaky Hand Cart','common','gear','delivery','{"coin_bonus":1}'),
('RST-044','restaurant','Push Scooter','common','gear','delivery','{"coin_bonus":1}'),
('RST-045','restaurant','Rusty Moped','common','gear','delivery','{"coin_bonus":1}'),
('RST-046','restaurant','Tricycle','common','gear','delivery','{"coin_bonus":1}'),
('RST-047','restaurant','Skateboard','common','gear','delivery','{"coin_bonus":1}'),
('RST-048','restaurant','Roller Skates','common','gear','delivery','{"coin_bonus":1}'),
('RST-049','restaurant','Second-Hand Bike','common','gear','delivery','{"coin_bonus":1}'),
('RST-050','restaurant','Borrowed Tandem','common','gear','delivery','{"coin_bonus":1}'),
('RST-051','restaurant','Cargo Bike','rare','gear','delivery','{"coin_bonus":2}'),
('RST-052','restaurant','Electric Scooter','rare','gear','delivery','{"coin_bonus":2}'),
('RST-053','restaurant','Zippy Moped','rare','gear','delivery','{"coin_bonus":2}'),
('RST-054','restaurant','Delivery Trike','rare','gear','delivery','{"coin_bonus":2}'),
('RST-055','restaurant','Electric Bike','rare','gear','delivery','{"coin_bonus":2}'),
('RST-056','restaurant','Little Van','rare','gear','delivery','{"coin_bonus":2}'),
('RST-057','restaurant','Electric Van','epic','gear','delivery','{"coin_bonus":3}'),
('RST-058','restaurant','Racing Moped','epic','gear','delivery','{"coin_bonus":3}'),
('RST-059','restaurant','Rocket Scooter','epic','gear','delivery','{"coin_bonus":3}'),
('RST-060','restaurant','The Delivery Drone Fleet','legendary','gear','delivery','{"coin_bonus":4}'),
('RST-061','restaurant','Plastic Chairs','common','cosmetic','decor','{}'),
('RST-062','restaurant','Paper Lanterns','common','cosmetic','decor','{}'),
('RST-063','restaurant','Potted Plant','common','cosmetic','decor','{}'),
('RST-064','restaurant','Fairy Lights','common','cosmetic','decor','{}'),
('RST-065','restaurant','Checked Tablecloths','common','cosmetic','decor','{}'),
('RST-066','restaurant','Chalkboard Menu','common','cosmetic','decor','{}'),
('RST-067','restaurant','Bunting','common','cosmetic','decor','{}'),
('RST-068','restaurant','Neon Strip Lights','rare','cosmetic','decor','{}'),
('RST-069','restaurant','Jukebox','rare','cosmetic','decor','{}'),
('RST-070','restaurant','Living Wall','rare','cosmetic','decor','{}'),
('RST-071','restaurant','Fish Tank','rare','cosmetic','decor','{}'),
('RST-072','restaurant','Crystal Chandelier','epic','cosmetic','decor','{}'),
('RST-073','restaurant','Indoor Waterfall','epic','cosmetic','decor','{}'),
('RST-074','restaurant','Rooftop Garden','legendary','cosmetic','decor','{}'),
('RST-075','restaurant','Plain Apron','common','cosmetic','uniform','{}'),
('RST-076','restaurant','Paper Hat','common','cosmetic','uniform','{}'),
('RST-077','restaurant','Hairnet','common','cosmetic','uniform','{}'),
('RST-078','restaurant','Stripy Apron','common','cosmetic','uniform','{}'),
('RST-079','restaurant','Baseball Cap','common','cosmetic','uniform','{}'),
('RST-080','restaurant','Polo Shirt','common','cosmetic','uniform','{}'),
('RST-081','restaurant','Neckerchief','common','cosmetic','uniform','{}'),
('RST-082','restaurant','Chef''s Whites','rare','cosmetic','uniform','{}'),
('RST-083','restaurant','Denim Apron','rare','cosmetic','uniform','{}'),
('RST-084','restaurant','Bandana','rare','cosmetic','uniform','{}'),
('RST-085','restaurant','Bow Tie','rare','cosmetic','uniform','{}'),
('RST-086','restaurant','Golden Chef''s Hat','epic','cosmetic','uniform','{}'),
('RST-087','restaurant','Sequin Jacket','epic','cosmetic','uniform','{}'),
('RST-088','restaurant','Handwritten Sign','common','cosmetic','sign','{}'),
('RST-089','restaurant','Cardboard Sign','common','cosmetic','sign','{}'),
('RST-090','restaurant','Painted Board','common','cosmetic','sign','{}'),
('RST-091','restaurant','Sandwich Board','common','cosmetic','sign','{}'),
('RST-092','restaurant','Flag','common','cosmetic','sign','{}'),
('RST-093','restaurant','Sticker Sign','common','cosmetic','sign','{}'),
('RST-094','restaurant','Light-Up Sign','rare','cosmetic','sign','{}'),
('RST-095','restaurant','Spinning Sign','rare','cosmetic','sign','{}'),
('RST-096','restaurant','Retro Sign','rare','cosmetic','sign','{}'),
('RST-097','restaurant','Mural','rare','cosmetic','sign','{}'),
('RST-098','restaurant','Giant Neon Sign','epic','cosmetic','sign','{}'),
('RST-099','restaurant','Digital Billboard','epic','cosmetic','sign','{}'),
('RST-100','restaurant','Hot Air Balloon Advert','legendary','cosmetic','sign','{}')
on conflict (id) do nothing;

insert into crates (id, theme, name, price, items_per_crate, odds, active)
values ('restaurant-crate', 'restaurant', 'Supply Crate', 100, 3, '{"common":70,"rare":20,"epic":8,"legendary":2}', true)
on conflict (id) do nothing;

-- Three gear slots instead of one captain, so let the bonus stack a bit further. Football tops out at 4 anyway.
create or replace function public.game_perks(p_game uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
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
end $function$;

-- Kids pick their venture (cuisine) from the ones unlocked at their rank tier. Earlier ones stay unlocked.
create or replace function public.choose_venture(p_game uuid, p_flavour text)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare g child_games; f theme_flavours;
begin
  select * into g from child_games where id = p_game for update;
  if g.id is null or not public.owns_child(g.child_id) then raise exception 'Game not found'; end if;
  select * into f from theme_flavours where id = p_flavour and theme = g.theme;
  if f.id is null then raise exception 'That venture is not part of this game'; end if;
  if f.unlock_tier > g.rank_tier then raise exception 'You have not unlocked that venture yet'; end if;
  update child_games set flavour = f.id where id = p_game;
  return jsonb_build_object('flavour', f.id, 'name', f.name, 'words', f.words);
end $function$;
revoke all on function public.choose_venture(uuid, text) from public, anon;
grant execute on function public.choose_venture(uuid, text) to authenticated;

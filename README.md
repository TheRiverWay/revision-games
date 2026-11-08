# Revision Games

Custom GCSE revision games, one folder per game, all sharing the Revision Games Supabase project.

- `football/` Football Manager Maths (GCSE Foundation maths, AQA)
- `tycoon/` Tycoon Maths: one page for every tycoon skin, driven by the `themes` table. `tycoon/` is Kitchen Tycoon (restaurant); `tycoon/?skin=garage` will be Garage Tycoon once it has collectibles and a crate.

## How tycoon skins work

- Question wording is written once under the `tycoon` theme, with word slots like `{items}`, `{supply}`, `{staff}`. Skins set `themes.wording_theme = 'tycoon'`.
- Words are filled in this order, later ones winning: `themes.default_words`, then the kid's venture (`theme_flavours.words`), then the kid's own names (`child_games.custom_names`).
- Ventures unlock by rank tier (`theme_flavours.unlock_tier`). The kid picks one at the start and a new one at each rank-up via `choose_venture`, which checks the unlock on the server.
- A new tycoon skin needs a `themes` row, its venture word packs, collectibles and a crate. No new questions and no code.

Hosted on GitHub Pages. Questions, tips, worked explanations and answer checking live in Supabase, so most content fixes need no change here.

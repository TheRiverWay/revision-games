# LevelWise

GCSE maths revision games themed on the games kids love. Live at https://levelwise.co.uk.

Static pages (plain HTML, CSS and JavaScript, no framework or build step) on Netlify, talking directly to Supabase (Postgres, auth) from the browser. Everything that must be trusted (serving and marking questions, rewards, admin) runs inside Postgres as `SECURITY DEFINER` functions, with row level security on every table.

## Layout

| Path | What it is |
|---|---|
| `index.html` | Public front page |
| `tycoon/` | The game. One page for every tycoon-style skin, picked by `?skin=<theme id>` (default `restaurant`, Kitchen Tycoon; `military` is Field Command) |
| `check/` | Starting check: 26 unthemed questions that set a child's focus topics |
| `account/` | Forgot or change password, request account deletion |
| `review/` | Tutor question review: approve a template, flag it, or reject number sets |
| `admin/` | Families, children, game assignment, tutors, deletion requests |
| `football/` | Football Manager skin (parked, not in v1) |
| `audio/` | Background music (self-hosted, 80 kbps). Sound effects are synthesised in the page, no files. Music and effects each have an on/off switch remembered per device |
| `fonts/`, `vendor/`, `brand/` | Self-hosted fonts, pinned supabase-js, logos. No third-party scripts or fonts are loaded from anywhere else |
| `drafts/` | Pages not yet live (privacy notice draft). Not deployed |
| `supabase/` | Database schema and how to rebuild it; see `supabase/README.md` |
| `tests/` | One jsdom suite per page, run against a mock Supabase client |
| `scripts/` | `stage-site.js` picks the published files; `build-deploy.sh` builds a zip as a manual fallback |
| `netlify.toml` | Netlify build: tests, then publish `dist/` |

Each page is a single self-contained HTML file. The Supabase URL and publishable key sit near the top of each page's script; the publishable key is safe to ship because row level security does the protecting.

## How questions and themes work

- `question_templates` holds 50 theme-free GCSE Foundation templates (formula, tip, worked steps, common wrong answers). `question_variants` holds the number sets for each, with the stored answer and marking tolerance. `template_spec_refs` maps every template to DfE, AQA, Edexcel and OCR.
- `theme_wording` has one wording row per template per theme, with slots: `{A}`, `{B}` for numbers and `{biz}`, `{item}`, `{supply}` and so on for theme words. Tycoon skins share the `tycoon` rows via `themes.wording_theme`.
- Theme words are filled in this order, later winning: `themes.default_words`, then the venture (`theme_flavours.words`, unlocked by rank tier), then the kid's own names (`child_games.custom_names`).
- A new tycoon skin is a `themes` row, its venture word packs, collectibles and a crate. No new questions and no code.
- `next_question()` picks what to ask (due spaced-repetition reviews, then focus topics, then the rest) and never returns the answer. `submit_answer()` marks on the server via `answer_is_correct()`, then awards cash, rank and the next review date.

## Working on it

```sh
npm install      # jsdom, for the tests
npm test         # every page suite; non-zero exit on any failure
```

Open a page by serving the folder (for example `npx serve .`) and visiting `/tycoon/`. It talks to the live Supabase project, so use a test account.

## Deploying

Netlify (site `levelwise-uk`) deploys from GitHub on every push to `main`. `netlify.toml` runs `npm ci`, the tests, then `scripts/stage-site.js`, which copies only the site folders into `dist/` and publishes that. If a test fails the deploy stops and the live site stays as it was. Tests, the database schema, drafts and scripts are never published.

Manual fallback: `scripts/build-deploy.sh` builds the same files as `../levelwise-netlify.zip` to drag onto Netlify's Deploys tab.

## Known rough edges

- The worked-solution expression engine (`WORK_FN`, `workEval`, `workLine`) is copied into `tycoon/`, `review/` and `football/`. It should become one shared file.
- The badge-palette restyle was added as a "LevelWise brand layer" block at the end of each page's styles rather than replacing the older styles.
- `tycoon/index.html` is about 1,000 lines with markup, styles and script together; it would split cleanly into separate files.

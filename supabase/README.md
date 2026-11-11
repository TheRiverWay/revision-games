# Database (Supabase)

The live project is "Revision Games" in London (eu-west-2), ref `ceslgssjxcgqtgqtymqv`.

## What's here

- `schema/` is the source of truth for the database structure, exported from the live project on 10 Nov 2026. Run the files in order on a fresh Supabase project:
  1. `01_tables.sql`: 26 tables, keys, check constraints, foreign keys, indexes
  2. `02_functions.sql`: all 56 functions (checked byte for byte against the live database)
  3. `03_security.sql`: triggers, row level security, 29 policies, column grants and function grants
- `history/` holds the one-off SQL files that were run while building (some include seed data). They are kept for reference only; `schema/` already contains their end result. Don't re-run them on the live database.

## Rebuilding a copy from scratch

1. Create a Supabase project (London region). Extensions `pgcrypto` and `uuid-ossp` are on by default.
2. Run the three `schema/` files in order in the SQL editor (or with `psql`).
3. Copy the content tables from the live project. The content is data, not code, so it isn't in the repo; take it with `pg_dump` using the live database's connection string (Project Settings, Database):

   ```sh
   pg_dump "$LIVE_DB_URL" --data-only --no-owner \
     -t public.themes -t public.theme_flavours -t public.theme_stat_rules \
     -t public.question_templates -t public.question_variants -t public.theme_wording \
     -t public.template_spec_refs -t public.collectibles -t public.crates -t public.league_teams \
     > content.sql
   psql "$NEW_DB_URL" -f content.sql
   ```

   Load `themes` before the rest (the dump orders tables alphabetically; run it twice if a foreign key complains, or disable triggers for the load).
4. Authentication settings (dashboard, not SQL): Site URL `https://levelwise.co.uk/tycoon/`; redirect URLs `https://levelwise.co.uk/**`; custom SMTP host `smtp.resend.com`, port 465, user `resend`, password = a Resend API key, sender `no-reply@levelwise.co.uk`.
5. Sign up on the site, then make yourself admin: `insert into admins (user_id) select id from auth.users where email = 'you@example.com';`
6. Point the pages at the new project: the Supabase URL and publishable key are near the top of each page's script.

## Making changes

- Change the live database with a migration (Supabase SQL editor or `supabase db push`), then re-export the affected part of `schema/` so the repo stays the source of truth.
- Functions are `SECURITY DEFINER` with a fixed `search_path`; new browser-callable ones need `revoke ... from public, anon` and `grant execute ... to authenticated` (see `03_security.sql`).
- New tables get row level security switched on automatically by the `ensure_rls` event trigger, so they are unreadable until you add a policy.
- The migration history in the live project starts at "12_security_and_speed_tidy"; earlier changes were made in the SQL editor and aren't recorded there. `schema/` replaces that gap.

## Backups

The project is on the free tier, which has no automatic backups. Until it moves to Pro, take a full dump now and then:

```sh
pg_dump "$LIVE_DB_URL" --no-owner -n public > levelwise-$(date +%F).sql
```

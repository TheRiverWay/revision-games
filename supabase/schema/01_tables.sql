-- LevelWise schema, part 1: tables, constraints, indexes.
-- Exported from the live Supabase project (ref ceslgssjxcgqtgqtymqv) on 2026-11-10; updated 2026-11-11.
-- Run the files in supabase/schema/ in number order on a fresh Supabase project.
-- Relies on Supabase's built-in auth schema (auth.users, auth.uid()).

set search_path to public;

create table public.account_deletion_requests (
  id bigint generated always as identity,
  user_id uuid,
  email text,
  reason text,
  requested_at timestamp with time zone not null default now(),
  cancelled_at timestamp with time zone,
  done_at timestamp with time zone
);

create table public.admins (
  user_id uuid not null,
  created_at timestamp with time zone default now()
);

create table public.answers (
  id bigint generated always as identity,
  child_id uuid not null,
  template_id text,
  topic text not null,
  correct boolean,
  answered_at timestamp with time zone,
  variant_id bigint,
  template_version integer,
  served_at timestamp with time zone not null default now(),
  given_answer numeric,
  shown_text text,
  exam_mode boolean not null default false,
  credits_awarded integer not null default 0,
  given_text text,
  game_id uuid,
  match_id bigint,
  check_id bigint
);

create table public.check_sessions (
  id bigint generated always as identity,
  child_id uuid not null,
  subject text not null default 'maths'::text,
  tier text not null default 'Foundation'::text,
  plan text[] not null default '{}'::text[],
  started_at timestamp with time zone not null default now(),
  finished_at timestamp with time zone,
  question_count integer
);

create table public.child_collection (
  child_id uuid not null,
  collectible_id text not null,
  quantity integer not null default 1,
  equipped_slot text,
  game_id uuid not null,
  in_lineup boolean not null default false
);

create table public.child_focus_topics (
  child_id uuid not null,
  topic text not null,
  source text not null,
  set_at timestamp with time zone not null default now()
);

create table public.child_games (
  id uuid not null default gen_random_uuid(),
  child_id uuid not null,
  subject text not null default 'maths'::text,
  theme text not null,
  exam_board text not null default 'AQA'::text,
  tier text not null default 'Foundation'::text,
  custom_names jsonb not null default '{}'::jsonb,
  colours jsonb not null default '{}'::jsonb,
  credits integer not null default 0,
  rank_tier integer not null default 1,
  rank_level integer not null default 1,
  created_at timestamp with time zone not null default now(),
  rank_xp integer not null default 0,
  season integer not null default 1,
  flavour text,
  crates_since_epic integer not null default 0,
  crates_since_legendary integer not null default 0
);

create table public.child_mastery (
  child_id uuid not null,
  template_id text not null,
  box integer not null default 0,
  times_seen integer not null default 0,
  times_correct integer not null default 0,
  next_review_at timestamp with time zone not null default now(),
  last_seen_at timestamp with time zone
);

create table public.child_pins (
  child_id uuid not null,
  pin_hash text not null
);

create table public.children (
  id uuid not null default gen_random_uuid(),
  parent_id uuid not null default auth.uid(),
  tutor_id uuid,
  nickname text not null,
  avatar text,
  created_at timestamp with time zone not null default now(),
  tutor_consent_at timestamp with time zone
);

create table public.collectibles (
  id text not null,
  theme text not null,
  name text not null,
  rarity text not null,
  image_url text,
  kind text not null default 'cosmetic'::text,
  slot text,
  perks jsonb not null default '{}'::jsonb,
  unlock_tier integer not null default 1,
  story text
);

create table public.crate_openings (
  id bigint generated always as identity,
  child_id uuid not null,
  crate_id text not null,
  cost integer not null,
  items jsonb not null,
  opened_at timestamp with time zone not null default now(),
  game_id uuid
);

create table public.crates (
  id text not null,
  theme text not null,
  name text not null,
  price integer not null,
  items_per_crate integer not null default 1,
  odds jsonb not null,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  active boolean not null default true
);

-- Football (parked, not in v1)
create table public.league_results (
  game_id uuid not null,
  season integer not null,
  tier integer not null,
  round integer not null,
  home integer not null,
  away integer not null,
  home_goals integer not null,
  away_goals integer not null
);

create sequence public.league_teams_id_seq;
create table public.league_teams (
  id integer not null default nextval('league_teams_id_seq'::regclass),
  theme text not null,
  tier integer not null,
  name text not null,
  rating integer not null
);
alter sequence public.league_teams_id_seq owned by public.league_teams.id;

create sequence public.matches_id_seq;
create table public.matches (
  id bigint not null default nextval('matches_id_seq'::regclass),
  game_id uuid not null,
  season integer not null,
  tier integer not null,
  round integer not null,
  opponent_id integer not null,
  our_rating integer not null,
  status text not null default 'live'::text,
  our_goals integer not null default 0,
  their_goals integer not null default 0,
  events jsonb not null default '[]'::jsonb,
  credits_awarded integer not null default 0,
  season_end jsonb,
  created_at timestamp with time zone not null default now(),
  finished_at timestamp with time zone
);
alter sequence public.matches_id_seq owned by public.matches.id;

create table public.parents (
  id uuid not null,
  display_name text,
  privacy_version text,
  privacy_accepted_at timestamp with time zone,
  created_at timestamp with time zone not null default now()
);

create table public.question_templates (
  id text not null,
  topic text not null,
  spec_point text not null,
  tier text not null default 'Foundation'::text,
  difficulty integer not null default 1,
  template jsonb not null,
  status text not null default 'draft'::text,
  version integer not null default 1,
  calculator text not null default 'either'::text,
  subject text not null default 'maths'::text
);

create table public.question_variants (
  id bigint generated always as identity,
  template_id text not null,
  template_version integer not null default 1,
  vars jsonb not null,
  answer numeric,
  tolerance numeric not null default 0.06,
  status text not null default 'unchecked'::text,
  checked_by uuid,
  checked_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  answer_text text,
  accept text[] not null default '{}'::text[],
  exact_only boolean not null default false
);

create table public.template_reviews (
  id bigint generated always as identity,
  template_id text not null,
  template_version integer not null,
  reviewer uuid not null,
  verdict text not null,
  note text,
  created_at timestamp with time zone not null default now()
);

create table public.template_spec_refs (
  template_id text not null,
  board text not null,
  spec_ref text not null,
  spec_text text,
  tier text default 'Foundation'::text,
  verified boolean default false,
  source_url text,
  notes text
);

create table public.theme_flavours (
  id text not null,
  theme text not null,
  name text not null,
  words jsonb not null default '{}'::jsonb,
  sort integer not null default 0,
  unlock_tier integer not null default 1
);

create table public.theme_stat_rules (
  theme text not null,
  stat text not null,
  effect text not null,
  thresholds integer[] not null
);

create table public.theme_wording (
  template_id text not null,
  theme text not null,
  wording text not null
);

create table public.themes (
  id text not null,
  name text not null,
  status text not null default 'draft'::text,
  tier_names text[] not null default '{}'::text[],
  custom_name_fields jsonb not null default '[]'::jsonb,
  slots jsonb not null default '[]'::jsonb,
  currency_name text not null default 'coins'::text,
  notes text,
  has_league boolean not null default false,
  wording_theme text,
  default_words jsonb not null default '{}'::jsonb
);

create table public.theme_wording_history (
  id bigint generated always as identity primary key,
  template_id text not null,
  theme text not null,
  wording text not null,
  replaced_at timestamp with time zone not null default now(),
  reason text
);

create table public.tutors (
  id uuid not null,
  name text not null
);

-- Primary keys
alter table account_deletion_requests add constraint account_deletion_requests_pkey PRIMARY KEY (id);
alter table admins add constraint admins_pkey PRIMARY KEY (user_id);
alter table answers add constraint answers_pkey PRIMARY KEY (id);
alter table check_sessions add constraint check_sessions_pkey PRIMARY KEY (id);
alter table child_collection add constraint child_collection_pkey PRIMARY KEY (game_id, collectible_id);
alter table child_focus_topics add constraint child_focus_topics_pkey PRIMARY KEY (child_id, topic);
alter table child_games add constraint child_games_pkey PRIMARY KEY (id);
alter table child_mastery add constraint child_mastery_pkey PRIMARY KEY (child_id, template_id);
alter table child_pins add constraint child_pins_pkey PRIMARY KEY (child_id);
alter table children add constraint children_pkey PRIMARY KEY (id);
alter table collectibles add constraint collectibles_pkey PRIMARY KEY (id);
alter table crate_openings add constraint crate_openings_pkey PRIMARY KEY (id);
alter table crates add constraint crates_pkey PRIMARY KEY (id);
alter table league_teams add constraint league_teams_pkey PRIMARY KEY (id);
alter table matches add constraint matches_pkey PRIMARY KEY (id);
alter table parents add constraint parents_pkey PRIMARY KEY (id);
alter table question_templates add constraint question_templates_pkey PRIMARY KEY (id);
alter table question_variants add constraint question_variants_pkey PRIMARY KEY (id);
alter table template_reviews add constraint template_reviews_pkey PRIMARY KEY (id);
alter table template_spec_refs add constraint template_spec_refs_pkey PRIMARY KEY (template_id, board, spec_ref);
alter table theme_flavours add constraint theme_flavours_pkey PRIMARY KEY (id);
alter table theme_stat_rules add constraint theme_stat_rules_pkey PRIMARY KEY (theme, stat, effect);
alter table theme_wording add constraint theme_wording_pkey PRIMARY KEY (template_id, theme);
alter table themes add constraint themes_pkey PRIMARY KEY (id);
alter table tutors add constraint tutors_pkey PRIMARY KEY (id);

-- Unique and check constraints
alter table child_games add constraint child_games_child_id_subject_theme_key UNIQUE (child_id, subject, theme);
alter table account_deletion_requests add constraint account_deletion_requests_reason_check CHECK ((char_length(reason) <= 500));
alter table answers add constraint answers_check_or_game CHECK (((check_id IS NULL) OR (game_id IS NULL)));
alter table child_focus_topics add constraint child_focus_topics_source_check CHECK ((source = ANY (ARRAY['check'::text, 'tutor'::text, 'parent'::text, 'admin'::text])));
alter table collectibles add constraint collectibles_kind_chk CHECK ((kind = ANY (ARRAY['gear'::text, 'cosmetic'::text])));
alter table collectibles add constraint collectibles_rarity_check CHECK ((rarity = ANY (ARRAY['common'::text, 'rare'::text, 'epic'::text, 'legendary'::text])));
alter table crates add constraint crates_items_per_crate_check CHECK (((items_per_crate >= 1) AND (items_per_crate <= 10)));
alter table crates add constraint crates_price_check CHECK ((price >= 0));
alter table question_templates add constraint question_templates_calculator_chk CHECK ((calculator = ANY (ARRAY['calculator'::text, 'non-calculator'::text, 'either'::text])));
alter table question_templates add constraint question_templates_subject_chk CHECK ((subject = ANY (ARRAY['maths'::text, 'biology'::text, 'chemistry'::text, 'physics'::text, 'combined science'::text, 'english'::text])));
alter table question_variants add constraint question_variants_status_check CHECK ((status = ANY (ARRAY['unchecked'::text, 'approved'::text, 'rejected'::text])));
alter table template_reviews add constraint template_reviews_note_check CHECK ((char_length(note) <= 1000));
alter table template_reviews add constraint template_reviews_verdict_check CHECK ((verdict = ANY (ARRAY['approved'::text, 'needs_changes'::text])));
alter table template_spec_refs add constraint template_spec_refs_board_check CHECK ((board = ANY (ARRAY['DfE'::text, 'AQA'::text, 'Edexcel'::text, 'OCR'::text])));
alter table theme_stat_rules add constraint theme_stat_rules_effect_check CHECK ((effect = ANY (ARRAY['coin_bonus'::text, 'free_hints'::text, 'streak_shields'::text])));
alter table themes add constraint themes_status_check CHECK ((status = ANY (ARRAY['live'::text, 'draft'::text, 'system'::text])));

-- Foreign keys
alter table account_deletion_requests add constraint account_deletion_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table admins add constraint admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table answers add constraint answers_check_id_fkey FOREIGN KEY (check_id) REFERENCES check_sessions(id) ON DELETE CASCADE;
alter table answers add constraint answers_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table answers add constraint answers_game_id_fkey FOREIGN KEY (game_id) REFERENCES child_games(id) ON DELETE SET NULL;
alter table answers add constraint answers_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id);
alter table answers add constraint answers_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES question_variants(id);
alter table check_sessions add constraint check_sessions_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table child_collection add constraint child_collection_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table child_collection add constraint child_collection_collectible_id_fkey FOREIGN KEY (collectible_id) REFERENCES collectibles(id);
alter table child_collection add constraint child_collection_game_id_fkey FOREIGN KEY (game_id) REFERENCES child_games(id) ON DELETE CASCADE;
alter table child_focus_topics add constraint child_focus_topics_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table child_games add constraint child_games_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table child_games add constraint child_games_flavour_fkey FOREIGN KEY (flavour) REFERENCES theme_flavours(id);
alter table child_games add constraint child_games_theme_fkey FOREIGN KEY (theme) REFERENCES themes(id);
alter table child_mastery add constraint child_mastery_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table child_mastery add constraint child_mastery_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id) ON DELETE CASCADE;
alter table child_pins add constraint child_pins_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table children add constraint children_parent_fk FOREIGN KEY (parent_id) REFERENCES parents(id) ON DELETE CASCADE;
alter table children add constraint children_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table children add constraint children_tutor_id_fkey FOREIGN KEY (tutor_id) REFERENCES tutors(id);
alter table collectibles add constraint collectibles_theme_fk FOREIGN KEY (theme) REFERENCES themes(id);
alter table crate_openings add constraint crate_openings_child_id_fkey FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
alter table crate_openings add constraint crate_openings_crate_id_fkey FOREIGN KEY (crate_id) REFERENCES crates(id);
alter table crate_openings add constraint crate_openings_game_id_fkey FOREIGN KEY (game_id) REFERENCES child_games(id) ON DELETE CASCADE;
alter table crates add constraint crates_theme_fk FOREIGN KEY (theme) REFERENCES themes(id);
alter table league_results add constraint league_results_game_id_fkey FOREIGN KEY (game_id) REFERENCES child_games(id) ON DELETE CASCADE;
alter table league_teams add constraint league_teams_theme_fkey FOREIGN KEY (theme) REFERENCES themes(id);
alter table matches add constraint matches_game_id_fkey FOREIGN KEY (game_id) REFERENCES child_games(id) ON DELETE CASCADE;
alter table matches add constraint matches_opponent_id_fkey FOREIGN KEY (opponent_id) REFERENCES league_teams(id);
alter table parents add constraint parents_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table question_variants add constraint question_variants_checked_by_fkey FOREIGN KEY (checked_by) REFERENCES tutors(id);
alter table question_variants add constraint question_variants_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id) ON DELETE CASCADE;
alter table template_reviews add constraint template_reviews_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table template_reviews add constraint template_reviews_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id) ON DELETE CASCADE;
alter table template_spec_refs add constraint template_spec_refs_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id);
alter table theme_flavours add constraint theme_flavours_theme_fkey FOREIGN KEY (theme) REFERENCES themes(id);
alter table theme_stat_rules add constraint theme_stat_rules_theme_fk FOREIGN KEY (theme) REFERENCES themes(id);
alter table theme_wording add constraint theme_wording_template_id_fkey FOREIGN KEY (template_id) REFERENCES question_templates(id) ON DELETE CASCADE;
alter table theme_wording add constraint theme_wording_theme_fk FOREIGN KEY (theme) REFERENCES themes(id);
alter table themes add constraint themes_wording_theme_fkey FOREIGN KEY (wording_theme) REFERENCES themes(id);
alter table tutors add constraint tutors_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Indexes
CREATE UNIQUE INDEX account_deletion_open ON public.account_deletion_requests USING btree (user_id) WHERE ((cancelled_at IS NULL) AND (done_at IS NULL));
CREATE INDEX answers_check_idx ON public.answers USING btree (check_id) WHERE (check_id IS NOT NULL);
CREATE INDEX answers_child_served_idx ON public.answers USING btree (child_id, served_at DESC);
CREATE INDEX answers_child_topic_idx ON public.answers USING btree (child_id, topic, answered_at DESC);
CREATE INDEX answers_game_idx ON public.answers USING btree (game_id);
CREATE INDEX answers_template_idx ON public.answers USING btree (template_id);
CREATE INDEX answers_variant_idx ON public.answers USING btree (variant_id);
CREATE INDEX check_sessions_child_idx ON public.check_sessions USING btree (child_id, started_at DESC);
CREATE INDEX child_collection_child_idx ON public.child_collection USING btree (child_id);
CREATE INDEX child_collection_item_idx ON public.child_collection USING btree (collectible_id);
CREATE UNIQUE INDEX child_collection_one_per_slot ON public.child_collection USING btree (game_id, equipped_slot) WHERE (equipped_slot IS NOT NULL);
CREATE INDEX child_games_child_idx ON public.child_games USING btree (child_id);
CREATE INDEX child_games_theme_idx ON public.child_games USING btree (theme);
CREATE INDEX child_mastery_due_idx ON public.child_mastery USING btree (child_id, next_review_at);
CREATE INDEX child_mastery_template_idx ON public.child_mastery USING btree (template_id);
CREATE INDEX children_parent_idx ON public.children USING btree (parent_id);
CREATE INDEX children_tutor_idx ON public.children USING btree (tutor_id);
CREATE INDEX crate_openings_child_idx ON public.crate_openings USING btree (child_id);
CREATE INDEX crate_openings_crate_idx ON public.crate_openings USING btree (crate_id);
CREATE INDEX crate_openings_game_idx ON public.crate_openings USING btree (game_id);
CREATE INDEX league_results_lookup ON public.league_results USING btree (game_id, season, tier);
CREATE UNIQUE INDEX matches_one_live ON public.matches USING btree (game_id) WHERE (status = 'live'::text);
CREATE INDEX question_templates_subject_tier_idx ON public.question_templates USING btree (subject, tier);
CREATE INDEX question_variants_checked_by_idx ON public.question_variants USING btree (checked_by);
CREATE INDEX question_variants_pick_idx ON public.question_variants USING btree (template_id, template_version, status);
CREATE INDEX template_reviews_tpl ON public.template_reviews USING btree (template_id, created_at DESC);

-- LevelWise schema, part 3: triggers, row level security, policies and grants.
-- Exported from the live Supabase project on 2026-11-10. Run after 01_tables.sql and 02_functions.sql.

set search_path to public;

-- Triggers
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
CREATE TRIGGER children_guard BEFORE UPDATE ON public.children FOR EACH ROW EXECUTE FUNCTION public.children_guard();

-- Event trigger: switch on RLS for any new table automatically
create event trigger ensure_rls on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function public.rls_auto_enable();

-- Row level security is on for every table. Tables with no policy (admins, child_pins,
-- league_*, matches) are reachable only through SECURITY DEFINER functions.
alter table public.account_deletion_requests enable row level security;
alter table public.admins enable row level security;
alter table public.answers enable row level security;
alter table public.check_sessions enable row level security;
alter table public.child_collection enable row level security;
alter table public.child_focus_topics enable row level security;
alter table public.child_games enable row level security;
alter table public.child_mastery enable row level security;
alter table public.child_pins enable row level security;
alter table public.children enable row level security;
alter table public.collectibles enable row level security;
alter table public.crate_openings enable row level security;
alter table public.crates enable row level security;
alter table public.league_results enable row level security;
alter table public.league_teams enable row level security;
alter table public.matches enable row level security;
alter table public.parents enable row level security;
alter table public.question_templates enable row level security;
alter table public.question_variants enable row level security;
alter table public.template_reviews enable row level security;
alter table public.template_spec_refs enable row level security;
alter table public.theme_flavours enable row level security;
alter table public.theme_stat_rules enable row level security;
alter table public.theme_wording enable row level security;
alter table public.themes enable row level security;
alter table public.tutors enable row level security;
alter table public.theme_wording_history enable row level security;  -- no policies: admin/service only

-- Policies
create policy "own deletion requests" on public.account_deletion_requests as PERMISSIVE for SELECT to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR is_admin()));
create policy "see answers" on public.answers as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "see checks" on public.check_sessions as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "see collection" on public.child_collection as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "see focus topics" on public.child_focus_topics as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "add games" on public.child_games as PERMISSIVE for INSERT to authenticated with check ((owns_child(child_id) AND (is_admin() OR (EXISTS ( SELECT 1
   FROM themes t
  WHERE ((t.id = child_games.theme) AND (t.status = 'live'::text)))))));
create policy "edit games" on public.child_games as PERMISSIVE for UPDATE to authenticated using (owns_child(child_id)) with check (owns_child(child_id));
create policy "remove games" on public.child_games as PERMISSIVE for DELETE to authenticated using (owns_child(child_id));
create policy "see games" on public.child_games as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "see mastery" on public.child_mastery as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "add children" on public.children as PERMISSIVE for INSERT to authenticated with check ((parent_id = ( SELECT auth.uid() AS uid)));
create policy "edit children" on public.children as PERMISSIVE for UPDATE to authenticated using ((parent_id = ( SELECT auth.uid() AS uid))) with check ((parent_id = ( SELECT auth.uid() AS uid)));
create policy "remove children" on public.children as PERMISSIVE for DELETE to authenticated using ((parent_id = ( SELECT auth.uid() AS uid)));
create policy "see children" on public.children as PERMISSIVE for SELECT to authenticated using (((parent_id = ( SELECT auth.uid() AS uid)) OR ((tutor_id = ( SELECT auth.uid() AS uid)) AND (tutor_consent_at IS NOT NULL))));
create policy "read collectibles" on public.collectibles as PERMISSIVE for SELECT to authenticated using (true);
create policy "see openings" on public.crate_openings as PERMISSIVE for SELECT to authenticated using (can_see_child(child_id));
create policy "read crates" on public.crates as PERMISSIVE for SELECT to authenticated using (true);
create policy "add own parent row" on public.parents as PERMISSIVE for INSERT to authenticated with check ((id = ( SELECT auth.uid() AS uid)));
create policy "edit own parent row" on public.parents as PERMISSIVE for UPDATE to authenticated using ((id = ( SELECT auth.uid() AS uid))) with check ((id = ( SELECT auth.uid() AS uid)));
create policy "see own parent row" on public.parents as PERMISSIVE for SELECT to authenticated using ((id = ( SELECT auth.uid() AS uid)));
create policy "read questions" on public.question_templates as PERMISSIVE for SELECT to authenticated using (true);
create policy "tutors read variants" on public.question_variants as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM tutors
  WHERE (tutors.id = ( SELECT auth.uid() AS uid)))));
create policy "reviewers read reviews" on public.template_reviews as PERMISSIVE for SELECT to authenticated using ((is_admin() OR (EXISTS ( SELECT 1
   FROM tutors t
  WHERE (t.id = ( SELECT auth.uid() AS uid))))));
create policy "read spec refs" on public.template_spec_refs as PERMISSIVE for SELECT to authenticated using (true);
create policy "read flavours" on public.theme_flavours as PERMISSIVE for SELECT to authenticated using (true);
create policy "read stat rules" on public.theme_stat_rules as PERMISSIVE for SELECT to authenticated using (true);
create policy "read wording" on public.theme_wording as PERMISSIVE for SELECT to authenticated using (true);
create policy "read themes" on public.themes as PERMISSIVE for SELECT to authenticated using (true);
create policy "read tutors" on public.tutors as PERMISSIVE for SELECT to authenticated using (true);

-- Table grants: Supabase's defaults (anon, authenticated and service_role get all table
-- privileges in public); RLS above is what actually restricts access. Two exceptions:
-- on children and child_games, signed-in users may only insert or update named columns,
-- so cash, ranks, flavour and parent can only change through server functions.
revoke insert, update on public.child_games, public.children from anon, authenticated;
grant insert (child_id, colours, custom_names, exam_board, subject, theme, tier) on public.child_games to authenticated;
grant update (colours, custom_names, exam_board, tier) on public.child_games to authenticated;
grant insert (avatar, nickname, parent_id, tutor_consent_at, tutor_id) on public.children to authenticated;
grant update (avatar, nickname, tutor_consent_at, tutor_id) on public.children to authenticated;

-- Function grants.
-- Pure text helpers stay executable by everyone (Postgres default):
--   answer_as_number, answer_numbers, children_guard, clean_answer, normalise_answer, number_list_match
-- Callable by signed-in users only:
do $$
declare f text;
begin
  foreach f in array array[
    'admin_add_child','admin_delete_account','admin_deletion_requests','admin_make_tutor','admin_overview',
    'assign_game','can_see_child','cancel_account_deletion','check_child_pin','check_results','choose_venture',
    'dev_add_credits','dev_answer','ensure_team','equip_item','focus_topic_names','game_perks','is_admin',
    'is_reviewer','league_info','match_event','my_account','next_check_question','next_question','open_crate',
    'owns_child','owns_game','rank_info','request_account_deletion','review_overview','review_template',
    'review_variant','set_child_pin','set_focus_topics','set_lineup','start_check','start_match',
    'submit_answer','submit_check_answer','unequip_slot']
  loop
    execute (select string_agg(format('revoke all on function public.%I(%s) from public, anon; grant execute on function public.%I(%s) to authenticated, service_role;',
                     p.proname, pg_get_function_identity_arguments(p.oid), p.proname, pg_get_function_identity_arguments(p.oid)), ' ')
             from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = f);
  end loop;
  -- Internal only (called by other functions or triggers, never from the browser):
  foreach f in array array[
    'answer_is_correct','finish_match','handle_new_user','league_fixtures','league_table','league_team_at',
    'match_json','rls_auto_enable','sim_goals','team_rating']
  loop
    execute (select string_agg(format('revoke all on function public.%I(%s) from public, anon, authenticated; grant execute on function public.%I(%s) to service_role;',
                     p.proname, pg_get_function_identity_arguments(p.oid), p.proname, pg_get_function_identity_arguments(p.oid)), ' ')
             from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = f);
  end loop;
end $$;

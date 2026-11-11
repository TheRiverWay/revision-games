-- LevelWise: account deletion (admin side). Run once in the Supabase SQL editor.
-- Needs the "account_deletion_requests" migration (applied 9 Nov by Claude).
-- Deleting the auth user cascades to parents, children, games, answers, checks,
-- collections, focus topics and PINs. The request row is kept (user_id set to null)
-- so there is a record that the deletion happened.

alter table public.account_deletion_requests drop constraint if exists account_deletion_requests_user_id_fkey;
alter table public.account_deletion_requests alter column user_id drop not null;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

create or replace function public.admin_delete_account(p_request bigint, p_confirm_email text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
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
end $$;

revoke all on function public.admin_delete_account(bigint, text) from public, anon;
grant execute on function public.admin_delete_account(bigint, text) to authenticated;

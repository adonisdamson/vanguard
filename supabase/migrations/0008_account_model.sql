-- 0008_account_model.sql
-- Self-signup flow: anyone can create an account; they land inactive/roleless
-- until an admin approves them and assigns a role + jurisdiction.

-- role is null until an admin sets it; account inactive until approved
alter table app_users alter column role drop default;
alter table app_users alter column role drop not null;
alter table app_users alter column is_active set default false;

alter table app_users add column if not exists requested_role user_role;
alter table app_users add column if not exists signup_source text default 'self';

-- Auto-create a pending app_users row on every new auth signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.app_users (id, full_name, email, role, is_active, signup_source)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    null,
    false,
    'self'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Self-insert fallback (if trigger is bypassed): user may only create their own
-- pending, role-less, inactive row.
drop policy if exists app_users_self_insert on app_users;
create policy app_users_self_insert on app_users for insert
  with check (id = auth.uid() and role is null and is_active = false);

-- The bootstrap admin trigger (0007) uses on conflict do update, which sets
-- is_active=true and role='admin' for the designated super-admin — that remains
-- unaffected by these changes since it runs as security definer / superuser.

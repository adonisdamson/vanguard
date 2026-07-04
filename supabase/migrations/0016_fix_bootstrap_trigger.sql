-- 0016_fix_bootstrap_trigger.sql
--
-- BUG: Migration 0008 added `handle_new_user` (trigger name: on_auth_user_created).
-- PostgreSQL fires AFTER INSERT triggers alphabetically. 'on_auth_user_created' < 'trg_bootstrap_admin',
-- so handle_new_user fires FIRST and inserts the admin row as role=null, is_active=false.
-- bootstrap_admin_on_signup then runs but its ON CONFLICT DO NOTHING silently skips the fix.
-- Result: admin always lands on the pending-approval screen and cannot log in.
--
-- Fix: change DO NOTHING → DO UPDATE so the bootstrap trigger always wins for this email.

create or replace function public.bootstrap_admin_on_signup()
returns trigger language plpgsql security definer as $$
begin
  if lower(new.email) = 'adonisdamson@gmail.com' then
    insert into public.app_users (id, full_name, email, role, is_active, created_at)
    values (new.id, 'Adonis Damson', new.email, 'admin', true, now())
    on conflict (id) do update set role = 'admin', is_active = true;
  end if;
  return new;
end;
$$;

-- Also fix any existing app_users row that is already broken (role=null, inactive)
update public.app_users au
set role = 'admin', is_active = true
from auth.users au2
where au.id = au2.id
  and lower(au2.email) = 'adonisdamson@gmail.com'
  and (au.role is null or au.is_active = false);

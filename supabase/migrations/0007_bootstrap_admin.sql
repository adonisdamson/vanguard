-- Bootstrap the first superadmin.
-- When adonisdamson@gmail.com signs in for the first time, their auth.users row
-- is created. This trigger fires immediately after and inserts an app_users row
-- with role='admin', bypassing RLS (runs as security definer / superuser context).
-- Safe: only inserts if no app_users row already exists for this auth UID.

create or replace function public.bootstrap_admin_on_signup()
returns trigger language plpgsql security definer as $$
begin
  if lower(new.email) = 'adonisdamson@gmail.com' then
    insert into public.app_users (id, full_name, email, role, is_active, created_at)
    values (
      new.id,
      'Adonis Damson',
      new.email,
      'admin',
      true,
      now()
    )
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

-- Fires on every new Supabase auth user insert (sign-up / first OAuth sign-in)
drop trigger if exists trg_bootstrap_admin on auth.users;
create trigger trg_bootstrap_admin
  after insert on auth.users
  for each row execute function public.bootstrap_admin_on_signup();

-- Also run immediately in case the auth.users row was already created
-- (e.g. if the user signed in before this migration was applied)
do $$
declare
  v_uid uuid;
  v_email text;
begin
  select id, email into v_uid, v_email
  from auth.users
  where lower(email) = 'adonisdamson@gmail.com'
  limit 1;

  if v_uid is not null then
    insert into public.app_users (id, full_name, email, role, is_active, created_at)
    values (v_uid, 'Adonis Damson', v_email, 'admin', true, now())
    on conflict (id) do update set role = 'admin', is_active = true;

    raise notice 'Admin row created/updated for existing user %', v_uid;
  else
    raise notice 'adonisdamson@gmail.com not yet in auth.users — trigger will handle it on first sign-in';
  end if;
end;
$$;

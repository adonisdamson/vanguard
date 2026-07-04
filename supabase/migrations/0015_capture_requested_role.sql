-- 0015_capture_requested_role.sql
-- handle_new_user() was inserting NULL for requested_role even when the
-- signup screen passes it in raw_user_meta_data. Update the trigger to
-- capture it, validating against the enum to avoid a bad cast.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
declare
  v_requested_role user_role;
begin
  -- Only accept valid non-admin roles as a hint; ignore anything else
  begin
    if new.raw_user_meta_data->>'requested_role' in ('personnel', 'higher_authority') then
      v_requested_role := (new.raw_user_meta_data->>'requested_role')::user_role;
    end if;
  exception when others then
    v_requested_role := null;
  end;

  insert into public.app_users (id, full_name, email, role, is_active, signup_source, requested_role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    null,
    false,
    'self',
    v_requested_role
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- =========================================================
-- HELPER FUNCTIONS (SECURITY DEFINER — bypass RLS to avoid recursion)
-- =========================================================
create or replace function public.get_my_role()
returns user_role
language sql stable security definer
as $$
  select role from app_users where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
as $$
  select exists (select 1 from app_users where id = auth.uid() and role = 'admin' and is_active = true);
$$;

-- =========================================================
-- ENABLE RLS EVERYWHERE
-- =========================================================
alter table app_users enable row level security;
alter table regions enable row level security;
alter table districts enable row level security;
alter table constituencies enable row level security;
alter table polling_stations enable row level security;
alter table members enable row level security;
alter table audit_log enable row level security;

-- =========================================================
-- APP_USERS POLICIES
-- =========================================================
create policy app_users_select on app_users for select
using (id = auth.uid() or get_my_role() = 'admin');

create policy app_users_insert_admin_only on app_users for insert
with check (get_my_role() = 'admin' or auth.uid() is null); -- null = trusted backend (service role)

create policy app_users_update on app_users for update
using (id = auth.uid() or get_my_role() = 'admin');

create policy app_users_delete_admin_only on app_users for delete
using (get_my_role() = 'admin');

-- Column-level restriction: only admin (or the trusted backend) may change role/is_active/email
create or replace function public.enforce_app_users_update_rules()
returns trigger language plpgsql security definer as $$
begin
  if auth.uid() is null then
    return new; -- trusted backend call via service role
  end if;
  if get_my_role() = 'admin' then
    return new;
  end if;
  if old.id is distinct from auth.uid() then
    raise exception 'Cannot update another user''s profile';
  end if;
  if new.role is distinct from old.role
     or new.is_active is distinct from old.is_active
     or new.email is distinct from old.email then
    raise exception 'Only an admin can change role, active status, or email';
  end if;
  return new;
end;
$$;

create trigger trg_enforce_app_users_update
before update on app_users
for each row execute function enforce_app_users_update_rules();

-- =========================================================
-- LOOKUP TABLE POLICIES (read: any authenticated operator; write: admin only)
-- =========================================================
create policy regions_select on regions for select using (auth.role() = 'authenticated');
create policy regions_write on regions for insert with check (get_my_role() = 'admin');
create policy regions_update on regions for update using (get_my_role() = 'admin');
create policy regions_delete on regions for delete using (get_my_role() = 'admin');

create policy districts_select on districts for select using (auth.role() = 'authenticated');
create policy districts_write on districts for insert with check (get_my_role() = 'admin');
create policy districts_update on districts for update using (get_my_role() = 'admin');
create policy districts_delete on districts for delete using (get_my_role() = 'admin');

create policy constituencies_select on constituencies for select using (auth.role() = 'authenticated');
create policy constituencies_write on constituencies for insert with check (get_my_role() = 'admin');
create policy constituencies_update on constituencies for update using (get_my_role() = 'admin');
create policy constituencies_delete on constituencies for delete using (get_my_role() = 'admin');

create policy polling_stations_select on polling_stations for select using (auth.role() = 'authenticated');
create policy polling_stations_write on polling_stations for insert with check (get_my_role() = 'admin');
create policy polling_stations_update on polling_stations for update using (get_my_role() = 'admin');
create policy polling_stations_delete on polling_stations for delete using (get_my_role() = 'admin');

-- =========================================================
-- MEMBERS POLICIES
-- =========================================================
create policy members_select_own on members for select
using (get_my_role() = 'personnel' and registered_by = auth.uid());

create policy members_select_reviewers on members for select
using (get_my_role() in ('higher_authority', 'admin'));

create policy members_insert on members for insert
with check (
  (get_my_role() in ('personnel', 'admin') and registered_by = auth.uid())
  or auth.uid() is null -- trusted backend (e.g. IP-capture update path)
);

create policy members_update on members for update
using (
  (get_my_role() = 'personnel' and registered_by = auth.uid())
  or get_my_role() in ('higher_authority', 'admin')
  or auth.uid() is null
);

create policy members_delete_admin_only on members for delete
using (get_my_role() = 'admin');

-- Column-level restriction: enforce who can touch which fields, and lock
-- a record once it's out of "pending" status for personnel.
create or replace function public.enforce_member_update_rules()
returns trigger language plpgsql security definer as $$
declare
  caller_role user_role;
begin
  if auth.uid() is null then
    return new; -- trusted backend call (service role) — e.g. IP capture, admin export flows
  end if;

  select role into caller_role from app_users where id = auth.uid();

  if caller_role = 'admin' then
    return new;
  end if;

  if caller_role = 'higher_authority' then
    if (new.first_name, new.last_name, new.date_of_birth, new.gender, new.phone, new.email,
        new.region_id, new.district_id, new.constituency_id, new.polling_station_id, new.ward,
        new.branch, new.membership_type, new.preferred_role, new.profession, new.employment_status,
        new.highest_academic_qualification, new.skills, new.photo_path, new.registered_by,
        new.registration_geolocation, new.registration_ip, new.registration_device_info, new.member_number)
       is distinct from
       (old.first_name, old.last_name, old.date_of_birth, old.gender, old.phone, old.email,
        old.region_id, old.district_id, old.constituency_id, old.polling_station_id, old.ward,
        old.branch, old.membership_type, old.preferred_role, old.profession, old.employment_status,
        old.highest_academic_qualification, old.skills, old.photo_path, old.registered_by,
        old.registration_geolocation, old.registration_ip, old.registration_device_info, old.member_number)
    then
      raise exception 'Higher authority may only update status, reviewed_by, and rejection_reason';
    end if;
    return new;
  end if;

  if caller_role = 'personnel' then
    if old.registered_by is distinct from auth.uid() then
      raise exception 'Personnel may only edit members they registered';
    end if;
    if old.status is distinct from 'pending' then
      raise exception 'Cannot edit a member record after it has been reviewed';
    end if;
    if new.status is distinct from old.status
       or new.reviewed_by is distinct from old.reviewed_by
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'Personnel cannot change status, reviewed_by, or rejection_reason';
    end if;
    return new;
  end if;

  raise exception 'Unauthorized role for this operation';
end;
$$;

create trigger trg_enforce_member_update
before update on members
for each row execute function enforce_member_update_rules();

-- =========================================================
-- AUDIT LOG: append-only, writable ONLY via this function
-- =========================================================
create or replace function public.log_audit_event(
  p_action text, p_target_table text, p_target_id text, p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer as $$
begin
  insert into audit_log(actor_id, action, target_table, target_id, metadata)
  values (auth.uid(), p_action, p_target_table, p_target_id, p_metadata);
end;
$$;

create policy audit_log_select_reviewers on audit_log for select
using (get_my_role() in ('admin', 'higher_authority'));
-- No insert/update/delete policies exist for regular clients — the table is
-- effectively locked except through log_audit_event(), which runs as SECURITY DEFINER.

create or replace function public.trg_audit_members() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    perform log_audit_event('member_created', 'members', new.id::text, jsonb_build_object('status', new.status));
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    perform log_audit_event('member_status_changed', 'members', new.id::text,
      jsonb_build_object('old_status', old.status, 'new_status', new.status, 'reason', new.rejection_reason));
  elsif tg_op = 'UPDATE' then
    perform log_audit_event('member_updated', 'members', new.id::text, '{}'::jsonb);
  end if;
  return new;
end;
$$;

create trigger trg_members_audit after insert or update on members
for each row execute function trg_audit_members();

create or replace function public.trg_audit_app_users() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    perform log_audit_event('operator_created', 'app_users', new.id::text, jsonb_build_object('role', new.role));
  elsif tg_op = 'UPDATE' and new.role is distinct from old.role then
    perform log_audit_event('role_changed', 'app_users', new.id::text,
      jsonb_build_object('old_role', old.role, 'new_role', new.role));
  elsif tg_op = 'UPDATE' and new.is_active is distinct from old.is_active then
    perform log_audit_event('account_status_changed', 'app_users', new.id::text,
      jsonb_build_object('is_active', new.is_active));
  end if;
  return new;
end;
$$;

create trigger trg_app_users_audit after insert or update on app_users
for each row execute function trg_audit_app_users();

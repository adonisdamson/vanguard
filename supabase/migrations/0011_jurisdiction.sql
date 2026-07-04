-- 0011_jurisdiction.sql
-- Every operator except a national admin is scoped to a jurisdiction.
-- Enforced in RLS — not just UI-level filtering.

alter table app_users add column if not exists assigned_region_id       int references regions(id);
alter table app_users add column if not exists assigned_district_id     int references districts(id);
alter table app_users add column if not exists assigned_constituency_id int references constituencies(id);

-- Helper functions used in RLS policies
create or replace function public.my_region_id() returns int
  language sql stable security definer as $$
    select assigned_region_id from app_users where id = auth.uid();
  $$;

create or replace function public.my_constituency_id() returns int
  language sql stable security definer as $$
    select assigned_constituency_id from app_users where id = auth.uid();
  $$;

-- Core access check: admin = national; higher_authority = scoped to constituency
-- (or region if constituency is null); personnel = own records within constituency
create or replace function public.can_access_member(
  m_region_id int, m_constituency_id int, m_registered_by uuid
) returns boolean language sql stable security definer as $$
  select case
    when get_my_role() = 'admin' then true
    when get_my_role() = 'higher_authority' then
      (my_constituency_id() is null or m_constituency_id = my_constituency_id())
      and (my_region_id() is null     or m_region_id      = my_region_id())
    when get_my_role() = 'personnel' then
      m_registered_by = auth.uid()
      and (my_constituency_id() is null or m_constituency_id = my_constituency_id())
    else false
  end;
$$;

-- Replace the old per-role member select policies with one jurisdiction-aware policy
drop policy if exists members_select_own       on members;
drop policy if exists members_select_reviewers on members;
drop policy if exists members_select           on members;
drop policy if exists members_update           on members;

create policy members_select on members for select
  using (can_access_member(region_id, constituency_id, registered_by) or auth.uid() is null);

create policy members_update on members for update
  using (can_access_member(region_id, constituency_id, registered_by) or auth.uid() is null);

-- Tighten insert: personnel and higher_authority may only insert into their constituency
drop policy if exists members_insert on members;
create policy members_insert on members for insert
  with check (
    auth.uid() is null
    or (
      get_my_role() in ('personnel', 'higher_authority', 'admin')
      and registered_by = auth.uid()
      and (
        get_my_role() = 'admin'
        or my_constituency_id() is null
        or constituency_id = my_constituency_id()
      )
    )
  );

-- 0029_manager_role.sql
-- Adds the 'manager' role = party "Administrator" (Organiser/Treasurer/Communication).
--
-- manager gets the same member powers as higher_authority ("Coordinator"):
-- view + insert + fully edit + approve members within jurisdiction. It does NOT
-- get operator/role/password management or app_users writes — those stay 'admin'.
--
-- Also adds operator party_position + branch columns (display + the bulk
-- executive import from the constituency register).
--
-- NOTE: `alter type ... add value` must be committed before the value is used,
-- so run the ADD VALUE statement in its own transaction, then the rest.

-- ── Part 1 (run alone / first) ───────────────────────────────────────────────
alter type user_role add value if not exists 'manager';

-- ── Part 2 (run after Part 1 is committed) ───────────────────────────────────
alter table app_users add column if not exists party_position text;
alter table app_users add column if not exists branch text;

-- Jurisdiction check: manager behaves exactly like higher_authority. Bulk-imported
-- Tema West operators have null assignment ⇒ they see the whole constituency.
create or replace function public.can_access_member(
  m_region_id int, m_constituency_id int, m_registered_by uuid
) returns boolean language sql stable security definer as $$
  select case
    when get_my_role() = 'admin' then true
    when get_my_role() in ('higher_authority', 'manager') then
      (my_constituency_id() is null or m_constituency_id = my_constituency_id())
      and (my_region_id() is null     or m_region_id      = my_region_id())
    when get_my_role() = 'personnel' then
      m_registered_by = auth.uid()
      and (my_constituency_id() is null or m_constituency_id = my_constituency_id())
    else false
  end;
$$;

-- Member edit trigger: manager may fully edit members (like higher_authority/admin).
create or replace function public.enforce_member_update_rules()
returns trigger language plpgsql security definer as $$
declare
  caller_role user_role;
begin
  if auth.uid() is null then return new; end if;
  select role into caller_role from app_users where id = auth.uid();

  if caller_role in ('admin', 'higher_authority', 'manager') then return new; end if;

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

-- Members insert: managers may register members too (scoped like the others).
drop policy if exists members_insert on members;
create policy members_insert on members for insert
  with check (
    auth.uid() is null
    or (
      get_my_role() in ('personnel', 'higher_authority', 'manager', 'admin')
      and registered_by = auth.uid()
      and (
        get_my_role() = 'admin'
        or my_constituency_id() is null
        or constituency_id = my_constituency_id()
      )
    )
  );

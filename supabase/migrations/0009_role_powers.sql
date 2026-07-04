-- 0009_role_powers.sql
-- Higher Authority (Coordinator) can now INSERT and fully EDIT member records,
-- scoped to their jurisdiction (enforced in 0011_jurisdiction.sql RLS).

-- Higher authority may INSERT members
drop policy if exists members_insert on members;
create policy members_insert on members for insert
  with check (
    auth.uid() is null
    or (
      get_my_role() in ('personnel', 'higher_authority', 'admin')
      and registered_by = auth.uid()
    )
  );

-- Regenerate the member update trigger: higher_authority may edit any member
-- data field; personnel stays restricted to their own pending rows; admin unrestricted.
create or replace function public.enforce_member_update_rules()
returns trigger language plpgsql security definer as $$
declare
  caller_role user_role;
begin
  if auth.uid() is null then return new; end if;
  select role into caller_role from app_users where id = auth.uid();

  if caller_role in ('admin', 'higher_authority') then return new; end if;

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

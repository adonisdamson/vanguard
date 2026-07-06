-- 0022_rls_tighten.sql — close the anon-key RLS hole (B9 audit finding).
--
-- Several policies carried "or auth.uid() is null", added under the mistaken
-- belief the backend needed an escape hatch. The backend uses service_role,
-- which BYPASSES RLS entirely — under RLS, auth.uid() is null only for ANON
-- key traffic, and the anon key ships inside the public APK. Net effect until
-- this migration: anyone with the anon key could SELECT/INSERT/UPDATE members
-- (all PII) and INSERT app_users rows. Verified live before the fix: an
-- unauthenticated SELECT on members returned rows.
--
-- The uid-null escapes inside the enforce_* TRIGGERS are intentionally kept:
-- service_role bypasses policies but not triggers, so those escapes are what
-- allow legitimate backend writes.

drop policy if exists members_select on members;
create policy members_select on members for select
  using (can_access_member(region_id, constituency_id, registered_by));

drop policy if exists members_update on members;
create policy members_update on members for update
  using (can_access_member(region_id, constituency_id, registered_by));

drop policy if exists members_insert on members;
create policy members_insert on members for insert
  with check (
    get_my_role() in ('personnel', 'higher_authority', 'admin')
    and registered_by = auth.uid()
    and (
      get_my_role() = 'admin'
      or my_constituency_id() is null
      or constituency_id = my_constituency_id()
    )
  );

-- app_users rows are created by the signup trigger (security definer, bypasses
-- RLS) or the service-role backend — never by anon traffic.
drop policy if exists app_users_insert_admin_only on app_users;
create policy app_users_insert_admin_only on app_users for insert
  with check (get_my_role() = 'admin');

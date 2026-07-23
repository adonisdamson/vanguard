-- 0030: Operator visibility for Coordinators & Administrators.
--
-- Feedback: "all higher authorities, coordinators can see all operators".
-- Coordinators are Higher Authorities. Both they and Administrators (manager)
-- may now READ every operator row. Creation / suspension / role changes still
-- flow exclusively through the Worker (service_role) — this only widens SELECT,
-- it does not grant any write path.
drop policy if exists app_users_select on app_users;
create policy app_users_select on app_users for select
using (
  id = auth.uid()
  or get_my_role() in ('admin', 'higher_authority', 'manager')
);

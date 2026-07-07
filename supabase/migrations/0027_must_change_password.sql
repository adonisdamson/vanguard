-- 0027_must_change_password.sql
-- When an admin sets an operator's password (at creation or via reset), that
-- password is admin-chosen and known to the admin. Require the operator to
-- change it themselves on next sign-in so no admin-known credential persists.
-- The operator clears this flag by changing their own password.

alter table app_users
  add column if not exists must_change_password boolean not null default false;

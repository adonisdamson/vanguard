-- 0024_audit_taxonomy.sql — kill audit-log double entries and name events
-- for what they are.
--
-- Before: creating an operator (server upsert sets role during insert) or
-- approving a signup logged BOTH "operator_created" AND "role_changed" —
-- every real event appeared twice, and self-signups were indistinguishable
-- from admin-created accounts. Every screen reading the log looked spammy.
--
-- New taxonomy:
--   INSERT, role set    -> operator_created   (admin created a ready account)
--   INSERT, role null   -> access_requested   (self-signup awaiting approval)
--   UPDATE, null -> set -> operator_approved  (request approved; ONE event)
--   UPDATE, set -> set  -> role_changed       (genuine role change)
--   is_active flip      -> account_status_changed

create or replace function public.trg_audit_app_users() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    if new.role is null then
      perform log_audit_event('access_requested', 'app_users', new.id::text,
        jsonb_build_object('requested_role', new.requested_role));
    else
      perform log_audit_event('operator_created', 'app_users', new.id::text,
        jsonb_build_object('role', new.role));
    end if;
  elsif tg_op = 'UPDATE' and new.role is distinct from old.role then
    if old.role is null then
      perform log_audit_event('operator_approved', 'app_users', new.id::text,
        jsonb_build_object('role', new.role));
    else
      perform log_audit_event('role_changed', 'app_users', new.id::text,
        jsonb_build_object('old_role', old.role, 'new_role', new.role));
    end if;
  elsif tg_op = 'UPDATE' and new.is_active is distinct from old.is_active then
    perform log_audit_event('account_status_changed', 'app_users', new.id::text,
      jsonb_build_object('is_active', new.is_active));
  end if;
  return new;
end;
$$;

-- Purge historical noise: audit rows whose target row no longer exists
-- (test churn during development) say nothing useful to an auditor.
delete from audit_log
where target_table = 'app_users'
  and target_id not in (select id::text from app_users);

delete from audit_log
where target_table = 'members'
  and target_id not in (select id::text from members);

-- Collapse the historical double entries: drop the redundant role_changed
-- rows logged at the same moment as an operator_created/approval for the
-- same target (within 2 seconds).
delete from audit_log a
using audit_log b
where a.action = 'role_changed'
  and b.action = 'operator_created'
  and a.target_id = b.target_id
  and abs(extract(epoch from (a.created_at - b.created_at))) < 2;

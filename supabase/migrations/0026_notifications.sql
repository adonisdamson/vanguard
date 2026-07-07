-- 0026_notifications.sql — in-app notifications for new registrations + reviews.
--
-- Two events, per the requirement:
--   * a member is registered (pending)  -> notify every active reviewer
--     (coordinators + admins) that there is something to review;
--   * a member is approved/rejected     -> notify the personnel who
--     registered them that their submission was reviewed.

create table if not exists notifications (
  id          bigserial primary key,
  recipient_id uuid references app_users(id) on delete cascade not null,
  type        text not null,   -- new_registration | member_approved | member_rejected
  title       text not null,
  body        text,
  member_id   uuid,            -- optional deep-link target
  read        boolean not null default false,
  created_at  timestamptz default now()
);

create index if not exists idx_notifications_recipient
  on notifications (recipient_id, read, created_at desc);

alter table notifications enable row level security;

-- Recipients see and update (mark-read) only their own notifications.
drop policy if exists notifications_select_own on notifications;
create policy notifications_select_own on notifications for select
  using (recipient_id = auth.uid());

drop policy if exists notifications_update_own on notifications;
create policy notifications_update_own on notifications for update
  using (recipient_id = auth.uid());

-- Rows are only ever created by the SECURITY DEFINER triggers below.

-- New pending registration -> every active reviewer.
create or replace function public.notify_new_registration()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (recipient_id, type, title, body, member_id)
  select u.id,
         'new_registration',
         'New registration to review',
         new.first_name || ' ' || new.last_name || ' is awaiting review.',
         new.id
  from app_users u
  where u.is_active and u.role in ('higher_authority', 'admin');
  return new;
end;
$$;

drop trigger if exists trg_notify_new_registration on members;
create trigger trg_notify_new_registration
  after insert on members
  for each row when (new.status = 'pending')
  execute function notify_new_registration();

-- Member reviewed -> notify the registrar (skip if they reviewed their own).
create or replace function public.notify_member_reviewed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status
     and new.status in ('active', 'rejected')
     and new.registered_by is not null
     and new.registered_by is distinct from new.reviewed_by then
    insert into notifications (recipient_id, type, title, body, member_id)
    values (
      new.registered_by,
      case when new.status = 'active' then 'member_approved' else 'member_rejected' end,
      case when new.status = 'active' then 'Member approved' else 'Member rejected' end,
      new.first_name || ' ' || new.last_name ||
        (case when new.status = 'active' then ' was approved.' else ' was rejected.' end),
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_member_reviewed on members;
create trigger trg_notify_member_reviewed
  after update on members
  for each row execute function notify_member_reviewed();

-- Mark-all-read helper (RLS-scoped to the caller).
create or replace function public.mark_all_notifications_read()
returns void language sql security definer set search_path = public as $$
  update notifications set read = true
  where recipient_id = auth.uid() and read = false;
$$;
grant execute on function public.mark_all_notifications_read() to authenticated;

# CLAUDE.md — Vanguard (NDC Membership Management App)

This file is the persistent source of truth for this project. Read it in
full at the start of every session before writing or changing any code.
When anything in this file conflicts with a one-off request in chat, ask
before deviating — don't silently override locked decisions below.

---

## 0. Coding Discipline (always in effect, every phase)

Derived from Karpathy's observed LLM coding pitfalls — installed once from
`https://github.com/multica-ai/andrej-karpathy-skills`, restated here so it's
never lost between sessions:

1. **Think before coding.** State assumptions explicitly. If a request is
   ambiguous, ask — don't silently pick an interpretation and run with it.
2. **Simplicity first.** Write the minimal code that solves exactly what was
   asked. No speculative features, no premature abstractions, no "while I'm
   here" additions.
3. **Surgical changes.** Edit only what the task requires. Match existing
   style. Don't refactor working code you weren't asked to touch.
4. **Goal-driven execution.** Every phase below has a "Definition of Done."
   Verify against it explicitly before declaring a phase complete — don't
   just stop when it looks finished.

Also: use the **UI-UX Pro Max** skill before building any screen, every
phase — not just once at project start.

---

## 1. Project Identity

- **Name:** Vanguard
- **Client:** National Democratic Congress (NDC), Ghana — starting with the
  Tema West Constituency register, built to scale party-wide
- **Purpose:** Replace a manual/Google-Forms membership register with a
  role-based mobile system for registering, reviewing, and administering
  party members
- **Platform (v1):** Android APK only. iOS is not in scope yet — don't add
  iOS-specific tooling or config unless asked.
- **Scale target:** 100,000+ member records. Every decision below (indexing,
  pagination, query patterns) is made with this in mind — don't build
  something that only works at demo scale.

---

## 2. Locked Architecture Decisions

Do not re-litigate these without an explicit instruction to change them:

| Layer | Choice | Role |
|---|---|---|
| Client | Flutter (Riverpod, go_router) | Android app |
| Auth | Firebase | **Auth only** — Google Sign-In + email/password. No Firestore, no Firebase Storage. |
| Database | Supabase (Postgres) | All relational data: members, operators, roles, lookup tables, audit log |
| File storage | Cloudinary (member photos) — *migration pending, Phase B*. Supabase Storage still in use until the swap lands. | Member photos only. Private/authenticated delivery via signed URLs — never a public URL. |
| Backend service | Cloudflare Workers (Hono) — lives in `worker/`. *(Was Railway/Express in `server/`, retained until the Workers cutover is verified in prod.)* | The *only* place the Supabase `service_role` key is ever loaded. Handles operator account creation, IP capture, exports, APK download proxy — anything requiring elevated privilege or server-verified data. |
| Icons | `phosphor_flutter` | Every icon in the app. Never Material default icons. |
| Loading/animation | `lottie`, recolored to NDC palette | Never generic spinners |
| Local offline queue | Hive | Registration submissions only, keep it simple |

**Security rule that must never be violated:** the Supabase `service_role`
key never appears in the Flutter app or gets committed anywhere client-side.
It lives only in the Cloudflare Worker's secrets (`wrangler secret put`).

**Why IP capture is server-side:** a phone cannot reliably determine its own
public IP (NAT/proxies/spoofing). It's captured by the Cloudflare Worker
reading the `CF-Connecting-IP` header, not by an on-device lookup.

---

## 3. Design System

- **Brand colors** (NDC official colors are red, white, green, black —
  these are placeholder hex until an official logo file gives exact values):

  | Color | Hex | Usage |
  |---|---|---|
  | NDC Green | `#006B3F` | Primary, headers, active states |
  | NDC Red | `#CE1126` | Alerts, destructive actions |
  | NDC Black | `#1A1A1A` | Text, icons |
  | NDC White | `#FFFFFF` | Backgrounds, cards |
  | Gold accent (verify) | `#FFC700` | Sparing use, badges |

- **Typography:** one deliberate Google Fonts pairing used everywhere (e.g.
  Sora for headings, Inter for body). Never leave the system font default.
- **Icons:** Phosphor Icons, one consistent style (duotone or fill — pick
  one and stay consistent app-wide).
- **Feel:** every loading/empty/error state must be intentional — skeleton
  loaders instead of spinners on lists, real copy on empty states, specific
  error messages tied to what actually failed. Haptic feedback on key
  actions (submit, approve/reject). No default Material 3 look, no
  templated-dashboard purple gradients.

---

## 4. Roles & Permissions

| Role | Can Do |
|---|---|
| **Admin** | Create/suspend/reactivate operator accounts, assign roles, manage lookup tables, view audit log, full access |
| **Higher Authority** | View all member records, dashboards/analytics, approve/reject pending registrations — cannot manage operator accounts |
| **Personnel** | Register members, edit only their own **pending** submissions, view their own submission history |

Flow: Personnel submits → `status='pending'` → Higher Authority
approves/rejects → `active` / `rejected`.

There is **no public self-registration** for operator accounts — only Admin
(via the Cloudflare Worker backend) creates Personnel/Higher Authority/Admin accounts.

---

## 5. Database Schema (Supabase / Postgres)

Live in `supabase/migrations/`. Treat these three files as the schema of
record — if a screen needs a field that isn't here, stop and ask rather than
silently adding a column.

**`0001_schema.sql`:**

```sql
create type user_role as enum ('admin', 'higher_authority', 'personnel');
create type member_status as enum ('pending', 'active', 'rejected', 'suspended');
create type membership_type as enum ('youth_member', 'adult_member', 'volunteer', 'executive', 'administration');
create type preferred_role as enum ('campaigning', 'events', 'media', 'fundraising');

create table app_users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text unique not null,
  phone text,
  role user_role not null default 'personnel',
  is_active boolean not null default true,
  created_by uuid references app_users(id),
  created_at timestamptz default now(),
  last_login_at timestamptz
);

create table regions (id serial primary key, name text unique not null);
create table districts (id serial primary key, region_id int references regions(id) not null, name text not null, unique(region_id, name));
create table constituencies (id serial primary key, district_id int references districts(id) not null, name text not null, unique(district_id, name));
create table polling_stations (id serial primary key, constituency_id int references constituencies(id) not null, name text not null, unique(constituency_id, name));

create table members (
  id uuid primary key default gen_random_uuid(),
  member_number text unique,
  first_name text not null,
  last_name text not null,
  date_of_birth date,
  gender text,
  phone text,
  email text,
  region_id int references regions(id),
  district_id int references districts(id),
  constituency_id int references constituencies(id),
  polling_station_id int references polling_stations(id),
  ward text,
  branch text,
  membership_type membership_type,
  preferred_role preferred_role,
  profession text,
  employment_status text,
  highest_academic_qualification text,
  skills text[],
  photo_path text,
  status member_status not null default 'pending',
  registered_by uuid references app_users(id) not null,
  reviewed_by uuid references app_users(id),
  rejection_reason text,
  registration_geolocation point,
  registration_ip text,
  registration_device_info jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table audit_log (
  id bigserial primary key,
  actor_id uuid references app_users(id),
  action text not null,
  target_table text,
  target_id text,
  metadata jsonb,
  created_at timestamptz default now()
);

create index idx_members_status on members(status);
create index idx_members_constituency on members(constituency_id);
create index idx_members_region on members(region_id);
create index idx_members_registered_by on members(registered_by);
create index idx_members_name_search on members using gin (to_tsvector('english', first_name || ' ' || last_name));
create index idx_members_phone on members(phone);
create index idx_members_member_number on members(member_number);
create index idx_members_created_at on members(created_at desc);
create index idx_audit_log_actor on audit_log(actor_id);
create index idx_audit_log_created_at on audit_log(created_at desc);
```

**`0002_rls_and_triggers.sql`:**

```sql
create or replace function public.get_my_role()
returns user_role language sql stable security definer as $$
  select role from app_users where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer as $$
  select exists (select 1 from app_users where id = auth.uid() and role = 'admin' and is_active = true);
$$;

alter table app_users enable row level security;
alter table regions enable row level security;
alter table districts enable row level security;
alter table constituencies enable row level security;
alter table polling_stations enable row level security;
alter table members enable row level security;
alter table audit_log enable row level security;

create policy app_users_select on app_users for select
using (id = auth.uid() or get_my_role() = 'admin');
create policy app_users_insert_admin_only on app_users for insert
with check (get_my_role() = 'admin' or auth.uid() is null);
create policy app_users_update on app_users for update
using (id = auth.uid() or get_my_role() = 'admin');
create policy app_users_delete_admin_only on app_users for delete
using (get_my_role() = 'admin');

create or replace function public.enforce_app_users_update_rules()
returns trigger language plpgsql security definer as $$
begin
  if auth.uid() is null then return new; end if;
  if get_my_role() = 'admin' then return new; end if;
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
before update on app_users for each row execute function enforce_app_users_update_rules();

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

create policy members_select_own on members for select
using (get_my_role() = 'personnel' and registered_by = auth.uid());
create policy members_select_reviewers on members for select
using (get_my_role() in ('higher_authority', 'admin'));
create policy members_insert on members for insert
with check (
  (get_my_role() in ('personnel', 'admin') and registered_by = auth.uid())
  or auth.uid() is null
);
create policy members_update on members for update
using (
  (get_my_role() = 'personnel' and registered_by = auth.uid())
  or get_my_role() in ('higher_authority', 'admin')
  or auth.uid() is null
);
create policy members_delete_admin_only on members for delete
using (get_my_role() = 'admin');

create or replace function public.enforce_member_update_rules()
returns trigger language plpgsql security definer as $$
declare
  caller_role user_role;
begin
  if auth.uid() is null then return new; end if;
  select role into caller_role from app_users where id = auth.uid();

  if caller_role = 'admin' then return new; end if;

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
before update on members for each row execute function enforce_member_update_rules();

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
```

**`0003_storage.sql`:**

```sql
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', false)
on conflict (id) do nothing;

create policy member_photos_select on storage.objects for select
using (bucket_id = 'member-photos' and auth.role() = 'authenticated');

create policy member_photos_insert on storage.objects for insert
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and get_my_role() in ('personnel', 'admin')
);

create policy member_photos_update on storage.objects for update
using (
  bucket_id = 'member-photos'
  and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() = 'admin')
);

create policy member_photos_delete on storage.objects for delete
using (bucket_id = 'member-photos' and get_my_role() = 'admin');
```

Upload path convention: `{auth.uid()}/{timestamp}_{filename}`. Bucket is
private — always display via `createSignedUrl(path, 3600)`, never a public URL.

---

## 6. Backend API Contract (Cloudflare Workers)

The only place the Supabase `service_role` key lives. Every route verifies
the caller's Supabase JWT before doing anything privileged.

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/api/members/:id/capture-metadata` | POST | Any operator who owns the record | Reads real IP from `x-forwarded-for`, accepts `{lat, lng}`, writes both to the member row |
| `/api/admin/operators` | POST | Admin | Creates Supabase Auth user + matching `app_users` row — the only way operator accounts are created |
| `/api/admin/operators/:id/suspend` | POST | Admin | Sets `is_active = false` |
| `/api/admin/operators/:id/reactivate` | POST | Admin | Sets `is_active = true` |
| `/api/admin/operators/:id/role` | POST | Admin | Changes an operator's role |
| `/api/exports/members` | POST | Higher Authority or Admin | Streams CSV/PDF for the current filter set, doesn't buffer full result client-side |

Registration flow: client inserts the member row directly via the Supabase
SDK (fast, offline-friendly) → immediately calls `capture-metadata` with the
new id. If that call fails (offline), the member row still exists as
`pending`; retry silently next time the app is online.

---

## 7. Non-Negotiable Engineering Rules

- Every list screen uses Supabase `.range()` pagination. Never fetch-all-then-
  filter-client-side, even for "small" lists — this app is built for 100k+ rows.
- Every WHERE/ORDER BY used in a query must be backed by an index in Section 5.
  If a new query pattern needs a new index, add the migration — don't just
  ship a slow query.
- `service_role` key: Cloudflare Worker secrets only. If you ever find yourself
  about to put it in a Flutter file or a committed config, stop and flag it.
- Column-level permission logic lives in Postgres triggers (Section 5), not
  just client-side checks — the client-side check is a UX nicety, the
  trigger is the actual enforcement.
- No public operator self-registration, ever.
- Photos are always accessed via signed URL, never a public bucket URL.

---

## 8. Build Plan — Phase by Phase

Update the checkboxes as work completes. Each phase has a **Definition of
Done** — verify against it explicitly before moving on, and report which
criteria passed/failed rather than just saying "done."

### Phase 0 — Foundation
- [ ] Flutter project scaffolded (`com.ndc.vanguard`, Android only, Riverpod, go_router)
- [ ] Folder structure: `lib/{core,features,shared}/`, features split by domain
- [ ] Dependencies installed: supabase_flutter, firebase_auth, firebase_core, google_sign_in, phosphor_flutter, lottie, geolocator, image_picker, cached_network_image, flutter_dotenv, hive
- [ ] `supabase/migrations/0001_schema.sql`, `0002_rls_and_triggers.sql`, `0003_storage.sql` created exactly as in Section 5 and applied
- [ ] Firebase configured for Auth only
- [ ] `/server` scaffolded (Node/Express or FastAPI) with the 6 endpoints from Section 6 stubbed and JWT verification wired
- [ ] `.env.example` (Flutter) and `/server/.env.example` created, no real secrets committed

**Definition of Done:** app builds and runs on an emulator showing a blank
Material shell; migrations apply cleanly against a fresh Supabase project;
`/server` starts locally and rejects unauthenticated requests to all 6 routes.

### Phase 1 — Design System + Auth
- [ ] Theme: NDC colors, font pairing, Phosphor icon style locked in a single theme file
- [ ] Lottie animations in place for splash, full-page loading, pull-to-refresh
- [ ] Splash screen
- [ ] Login (email/password + Google Sign-In)
- [ ] Post-login role lookup + routing to correct home (Personnel/Higher Authority/Admin), "pending approval" screen for users with no `app_users` row
- [ ] Forgot password flow

**Definition of Done:** a test user in each of the three roles logs in and
lands on a distinct, correctly-routed home screen; a Firebase user with no
`app_users` row sees the pending-approval screen instead of crashing or
landing on a default view.

### Phase 2 — Personnel: Registration
- [ ] Home screen with own-submission stats
- [ ] 4-step registration form matching the schema exactly
- [ ] Photo upload to `member-photos/{uid}/...`, path saved to `photo_path`
- [ ] Cascading region → district → constituency → polling station dropdowns
- [ ] Member insert + `member_number` auto-generation
- [ ] `capture-metadata` call wired after insert (GPS + server-side IP)
- [ ] "My Submissions" paginated list with status filter
- [ ] Offline queue (Hive) for registrations submitted with no connection

**Definition of Done:** a Personnel test account can complete a full
registration offline, see it sync once connectivity returns, and see it
appear correctly in "My Submissions"; attempting to edit a non-pending
record is blocked in the UI and would also be blocked by the DB trigger if forced.

### Phase 3 — Higher Authority: Review, Directory, Dashboard
- [ ] Dashboard metric cards + charts (fl_chart, NDC-styled)
- [ ] Review queue (pending members), approve/reject with reason
- [ ] Member directory: paginated, server-side search + filters
- [ ] Member detail with audit history
- [ ] Export triggers `/api/exports/members`

**Definition of Done:** a Higher Authority test account can approve and
reject records (with the DB confirming `reviewed_by`/`rejection_reason` set
correctly), search 1,000+ seeded test records without a client-side full
fetch, and successfully trigger an export.

### Phase 4 — Admin: Operators, Lookups, Audit
- [ ] Operator management screen wired to the 4 admin Railway endpoints
- [ ] Lookup table CRUD (regions/districts/constituencies/polling stations) via Supabase SDK directly
- [ ] Audit log viewer, paginated + filterable
- [ ] System overview stats

**Definition of Done:** an Admin test account can create a new operator
account end-to-end (new login actually works), suspend it (login then
fails), and see both actions reflected in the audit log.

### Phase 5 — Polish & Scale Pass
- [ ] Pagination audit across every list screen
- [ ] Index audit against Section 5
- [ ] Signed-URL image caching with Phosphor placeholder/error states
- [ ] Loading/empty/error state pass, on-brand throughout
- [ ] Pull-to-refresh with Lottie on all lists
- [ ] Offline degradation checked beyond registration
- [ ] Accessibility pass (contrast, font size, tap targets)

**Definition of Done:** written report listing what was checked and what was
fixed, not just "polish complete."

### Phase 6 — Android Release Build
- [ ] App name/icon/package finalized (real NDC logo if available by then)
- [ ] Release keystore generated and signing configured
- [ ] Version code/name set, minification enabled
- [ ] `flutter build apk --release` succeeds
- [ ] Final security checklist: no secrets committed, RLS verified active by
      attempting a cross-role query and confirming it fails, `service_role`
      key confirmed absent from the Flutter app

**Definition of Done:** signed APK path delivered, plus a short written
v1-vs-deferred summary.

---

## 9. Open Questions (resolve before the phase that needs them)

- Exact NDC brand hex — needed before Phase 6, nice to have by Phase 1.
- Data residency requirement for member PII — needed before provisioning
  Supabase/Railway regions in Phase 0.
- Real field connectivity conditions for Personnel — informs how much
  offline-queue robustness Phase 2 actually needs.

---

## 10. Assumptions Already Locked (don't re-ask about these)

- Firebase is Auth-only; everything else is Supabase.
- IP capture happens server-side via the Cloudflare Worker (`CF-Connecting-IP`), not on-device.
- Registration writes go client → Supabase directly, then client → the Cloudflare Worker
  for metadata capture (not routed entirely through the backend).
- No public operator self-registration.

# VANGUARD — NDC Membership Management App
## Full Build Plan + Complete Claude Code Prompt Pack (v2 — fully wired)

**Target:** Android APK (v1), Flutter, built to scale to 100k+ users
**Backend:** Supabase (Postgres + Storage + RLS) + a small Railway-hosted API for anything that must run server-side (service-role operations, real IP capture, exports)
**Auth:** Firebase (Google Sign-In + email/password) — nothing else lives in Firebase
**Client:** Claude Code, using the `UI-UX Pro Max` skill + Phosphor Icons + Lottie
**Party:** National Democratic Congress (NDC), Ghana

This version replaces every "figure it out" instruction from v1 with actual SQL, actual policies, and an actual API contract, so Claude Code has nothing left to guess.

---

## 0. Locked Assumptions

1. **Firebase = Auth only.** All data, files, roles, geolocation, and IP logs live in Supabase.
2. **Railway = the only place secrets with elevated privilege (Supabase `service_role` key) are ever used.** The Flutter app never holds the service role key. This matters for a 100k-user political app — a leaked service role key in an APK is a real incident.
3. **Real IP capture must happen server-side.** A Flutter client cannot reliably determine its own public IP (NAT, proxies, spoofing) — this is done by the Railway endpoint reading the request headers, not by an on-device "what's my IP" call.
4. **NDC brand colors** — party colors are confirmed as red, white, green, and black. Hex values below are close approximations; swap in the exact hex the moment you have an official logo/brand asset.

| Color | Approx Hex | Usage |
|---|---|---|
| NDC Green | `#006B3F` | Primary, headers, active states |
| NDC Red | `#CE1126` | Alerts, destructive actions |
| NDC Black | `#1A1A1A` | Text, icons |
| NDC White | `#FFFFFF` | Backgrounds, cards |
| Gold accent (verify) | `#FFC700` | Sparing use, badges |

---

## 1. Roles & Permissions

| Role | Can Do |
|---|---|
| **Admin** | Create/suspend operator accounts, assign roles, manage lookup tables, view audit log, full access |
| **Higher Authority** | View all member records, dashboards/analytics, approve/reject pending registrations — cannot manage operator accounts |
| **Personnel** | Register members, edit only their own **pending** submissions, view their submission history |

Flow: Personnel submits → `status='pending'` → Higher Authority approves/rejects → `active`/`rejected`.

---

## 2. Database Schema (Supabase / Postgres)

```sql
-- =========================================================
-- ENUMS
-- =========================================================
create type user_role as enum ('admin', 'higher_authority', 'personnel');
create type member_status as enum ('pending', 'active', 'rejected', 'suspended');
create type membership_type as enum ('youth_member', 'adult_member', 'volunteer', 'executive', 'administration');
create type preferred_role as enum ('campaigning', 'events', 'media', 'fundraising');

-- =========================================================
-- APP USERS (operators: personnel / higher_authority / admin)
-- =========================================================
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

-- =========================================================
-- LOOKUP TABLES (admin-manageable, cascading)
-- =========================================================
create table regions (id serial primary key, name text unique not null);
create table districts (id serial primary key, region_id int references regions(id) not null, name text not null, unique(region_id, name));
create table constituencies (id serial primary key, district_id int references districts(id) not null, name text not null, unique(district_id, name));
create table polling_stations (id serial primary key, constituency_id int references constituencies(id) not null, name text not null, unique(constituency_id, name));

-- =========================================================
-- MEMBERS (the party register)
-- =========================================================
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
  photo_path text, -- storage object path, e.g. "member-photos/{uid}/{file}.jpg" — NOT a public URL, bucket is private
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

-- =========================================================
-- AUDIT LOG (append-only, written only via SECURITY DEFINER function)
-- =========================================================
create table audit_log (
  id bigserial primary key,
  actor_id uuid references app_users(id),
  action text not null,
  target_table text,
  target_id text,
  metadata jsonb,
  created_at timestamptz default now()
);

-- =========================================================
-- INDEXES (mandatory at 100k+ rows)
-- =========================================================
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

---

## 3. Full RLS Policies & Business-Rule Triggers (complete SQL — nothing left for Claude Code to invent)

**Critical gotcha handled here:** helper functions that check a caller's role must query `app_users`, but `app_users` itself has RLS enabled — that would cause infinite recursion unless the helper functions are `SECURITY DEFINER` (they bypass RLS internally). This is done below. Also: Railway's backend calls use the Supabase **service role** key, which bypasses RLS entirely but still fires triggers — so every business-rule trigger below explicitly allows service-role/backend calls through (`auth.uid() is null`) rather than blocking them.

```sql
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
```

---

## 4. Storage Bucket — `member-photos` (complete policy set)

Path convention: **`{auth.uid()}/{timestamp}_{filename}`** — every uploaded file lives under the uploading operator's own UID folder. The `members.photo_path` column stores this path; the bucket is **private**, so the app always requests a short-lived **signed URL** to display a photo (never a public URL).

```sql
-- Create the bucket (private)
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', false)
on conflict (id) do nothing;

-- Any authenticated operator can view photos (needed for review + directory screens)
create policy member_photos_select on storage.objects for select
using (bucket_id = 'member-photos' and auth.role() = 'authenticated');

-- Personnel/Admin can upload only into their own UID-named folder
create policy member_photos_insert on storage.objects for insert
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and get_my_role() in ('personnel', 'admin')
);

-- Same rule for replacing a photo
create policy member_photos_update on storage.objects for update
using (
  bucket_id = 'member-photos'
  and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() = 'admin')
);

-- Only admin can delete photos outright
create policy member_photos_delete on storage.objects for delete
using (bucket_id = 'member-photos' and get_my_role() = 'admin');
```

Flutter-side contract: upload via `supabase.storage.from('member-photos').upload('${user.id}/${DateTime.now().millisecondsSinceEpoch}_photo.jpg', file)`, save the returned path into `photo_path`, and generate display URLs with `createSignedUrl(path, 3600)` (cache the signed URL for the session, don't regenerate per frame).

---

## 5. Railway Backend — Complete API Contract

This is a small service (Node.js + Express/NestJS, or Python + FastAPI — Claude Code's choice, keep it minimal) that is the **only** place the Supabase `service_role` key is ever loaded. Every endpoint verifies the caller's Supabase JWT first (via Supabase's public JWKS/anon client) before doing anything privileged.

| Endpoint | Method | Auth Required | Purpose |
|---|---|---|---|
| `/api/members/:id/capture-metadata` | POST | Any authenticated operator (must be the record's `registered_by`) | Reads the real client IP from request headers (`x-forwarded-for`), accepts a `{lat, lng}` body from the device's GPS, and writes both to `registration_ip` / `registration_geolocation` on the member row using the service role (bypasses the "personnel can only edit pending" trigger via `auth.uid() is null` path — but the endpoint itself still checks the caller owns the record before doing the write) |
| `/api/admin/operators` | POST | Admin only (role checked server-side against `app_users`) | Creates a new Supabase Auth user via `supabase.auth.admin.createUser()`, then inserts the matching `app_users` row. This is the **only** way new operator accounts are created — there is no public sign-up. |
| `/api/admin/operators/:id/suspend` | POST | Admin only | Sets `is_active = false` |
| `/api/admin/operators/:id/reactivate` | POST | Admin only | Sets `is_active = true` |
| `/api/exports/members` | POST | Higher Authority or Admin | Accepts the same filters as the directory screen, streams a CSV or PDF rather than requiring the client to hold the full result set in memory |

**Why `capture-metadata` is a separate call instead of doing it at insert time:** the client inserts the member row directly via the Supabase SDK (fast, works offline-then-syncs), then immediately calls this endpoint with the new row's id to fill in server-verifiable IP + confirm geolocation. If the call fails (e.g., offline), the member record still exists as `pending` with null IP/geo — not a blocker, just less metadata, and it can be retried.

---

## 6. Design & Feel Requirements

- **Icons:** Phosphor Icons exclusively (`phosphor_flutter`). No Material default icons anywhere.
- **Loading states:** Lottie animations recolored to NDC palette — no generic blue spinners.
- **No AI-slop look:** no default Material 3 purple gradients, no templated dashboard feel. Use `UI-UX Pro Max` skill on every screen — deliberate spacing, real typography hierarchy, real empty states, skeleton loaders instead of spinners for lists.
- **Feels human-built:** haptic feedback on submit, real transition animations, error messages tied to what actually went wrong (not generic "An error occurred").
- **Typography:** one strong pairing used everywhere, no system-font default.

---

## 7. Build Phases

| Phase | Deliverable |
|---|---|
| 0 | Repo setup, CLAUDE.md guardrails, full Supabase schema + RLS + triggers + storage bucket (from Sections 2–4), Firebase Auth config, Railway service scaffold |
| 1 | Design system + auth screens |
| 2 | Personnel: registration form + metadata capture + submission history |
| 3 | Higher Authority: review queue, directory, dashboard/analytics |
| 4 | Admin: operator management (via Railway endpoints), lookup tables, audit log |
| 5 | Polish: pagination audit, offline queue, image caching, accessibility |
| 6 | Signed Android release APK |

---

## 8. Claude Code Prompt Pack

Run in order, one phase per turn, confirming each before moving on.

### Setup Prompt (once, first)

```
Install the Karpathy coding-discipline guidelines before writing any code:

  git clone https://github.com/multica-ai/andrej-karpathy-skills.git /tmp/karpathy-skills

Copy /tmp/karpathy-skills/CLAUDE.md into this project's root as CLAUDE.md
(append if one already exists, don't overwrite).

Internalize its four principles for this entire project:
1. Think before coding — state assumptions explicitly, ask when ambiguous.
2. Simplicity first — minimal code for exactly what's asked, no speculative features.
3. Surgical changes — don't refactor things I didn't ask you to touch.
4. Goal-driven execution — verify against the success criteria I give you before
   declaring a phase done.

Also load and use the "UI-UX Pro Max" skill for every screen in this project —
check it before building any UI, every phase, not just once.

Confirm both are loaded, then wait for the next prompt.
```

### Phase 0 — Project Setup (fully wired, paste as one prompt)

````
Create a new Flutter project named "vanguard" (package: com.ndc.vanguard),
Android-only for now (minSdkVersion 23, targetSdkVersion latest stable).

1. Folder structure: lib/{core,features,shared}/, features split by domain
   (auth, members, dashboard, admin, profile), clean-architecture-lite split
   (presentation/application/data) — don't over-engineer beyond what a solo
   dev team can maintain.
2. State management: Riverpod. Routing: go_router.
3. Dependencies: supabase_flutter, firebase_auth, firebase_core, google_sign_in,
   phosphor_flutter, lottie, geolocator, image_picker, cached_network_image,
   flutter_dotenv, hive (or drift) for the offline queue.
4. Create supabase/migrations/0001_schema.sql with EXACTLY this content:

[PASTE SECTION 2 SQL HERE — the ENUMS through INDEXES block]

5. Create supabase/migrations/0002_rls_and_triggers.sql with EXACTLY this content:

[PASTE SECTION 3 SQL HERE — the full RLS/helper-function/trigger block]

6. Create supabase/migrations/0003_storage.sql with EXACTLY this content:

[PASTE SECTION 4 SQL HERE — the bucket + storage policies block]

Do not modify the logic in these three files — apply them as-is via the
Supabase CLI/migration tooling. If the Supabase CLI needs adjustments to run
them (e.g. extension requirements like pgcrypto for gen_random_uuid()), add
the minimum needed at the top of 0001_schema.sql and tell me what you added.

7. Set up Firebase project config for Auth ONLY (Google Sign-In + email/password).
   Do not touch Firestore or Firebase Storage.
8. Scaffold the Railway backend as a separate /server directory (Node.js +
   Express or Python + FastAPI, your choice — keep it minimal) implementing
   exactly the endpoints in this table, with JWT verification against Supabase
   on every route and the service_role key loaded only from environment
   variables (never hardcoded, never in the Flutter app):

   POST /api/members/:id/capture-metadata   — any authenticated operator who
     owns the record; reads IP from x-forwarded-for header, accepts {lat,lng}
     in the body, writes both to the member row via service role client.
   POST /api/admin/operators                — admin only; creates a Supabase
     Auth user via admin.createUser() then inserts the app_users row.
   POST /api/admin/operators/:id/suspend     — admin only; sets is_active=false.
   POST /api/admin/operators/:id/reactivate  — admin only; sets is_active=true.
   POST /api/exports/members                 — higher_authority or admin;
     accepts directory filters, streams CSV/PDF instead of buffering the
     full result set.

9. Create .env.example (Flutter) and /server/.env.example (Railway) with
   placeholders only — SUPABASE_URL, SUPABASE_ANON_KEY (Flutter),
   SUPABASE_SERVICE_ROLE_KEY (server only, never in Flutter), Firebase config
   keys. Do not commit real secrets.

Do not build any UI yet. Show me the folder structure and migration file
contents, then wait for my confirmation before Phase 1.
````

*(When you actually run this, replace the three `[PASTE SECTION X SQL HERE]` placeholders with the real SQL blocks from Sections 2, 3, and 4 above — keep the SQL exactly as written so the trigger logic and RLS recursion-avoidance stays correct.)*

### Phase 1 — Design System + Auth

```
Build the design system first, then auth screens.

Design system:
- NDC brand theme: primary green #006B3F, red #CE1126, black #1A1A1A,
  white #FFFFFF, gold accent #FFC700 (placeholders — I'll swap in exact
  brand hex once I have an official logo file).
- Typography: a strong Google Fonts pairing (e.g. Sora for headings, Inter
  for body) — no system font default.
- Icons: phosphor_flutter everywhere, one consistent style (duotone or fill),
  never Material default icons.
- Lottie loading animations recolored to the NDC palette for: splash screen,
  full-page loading, pull-to-refresh.
- Use the UI-UX Pro Max skill for deliberate spacing/hierarchy — no raw
  Material 3 defaults left unstyled.

Auth screens:
1. Splash screen: Lottie animation + Vanguard wordmark placeholder, NDC colors.
2. Login: email/password + "Continue with Google" (Firebase Auth), Phosphor
   icons on inputs, real inline validation.
3. After login, look up the user's role in Supabase app_users (matching
   auth.uid()). If no app_users row exists, show a "pending approval —
   contact your admin" screen; there is no self-registration. Otherwise
   route to the correct home (Personnel / Higher Authority / Admin) based
   on role.
4. Forgot password flow.

Every state (loading/error/empty) should feel intentional — no bare spinners,
no generic error text. Show me each screen, then wait for confirmation
before Phase 2.
```

### Phase 2 — Personnel: Member Registration

```
Build the Personnel role's core flow.

1. Home: quick stats (their submissions today/this week, pending vs approved
   counts pulled from their own rows only — RLS already restricts this),
   prominent "Register New Member" action.
2. Multi-step registration form matching the members schema exactly:
   Step 1 — Personal (name, DOB, gender, phone, email, photo via image_picker
     → upload to the member-photos bucket at path "{auth.uid()}/{timestamp}_
     {filename}" per the storage contract in Section 4; store the returned
     path in photo_path, not a public URL).
   Step 2 — Location: region → district → constituency → polling station as
     cascading dropdowns sourced live from the lookup tables (each dropdown
     queries filtered by the parent's id); ward and branch as free text.
   Step 3 — Party info: membership_type, preferred_role, profession,
     employment_status, highest_academic_qualification, skills (multi-select chips).
   Step 4 — Review & submit.
3. On submit: insert the member row directly via the Supabase client SDK
   (status='pending', registered_by=current user, auto-generate member_number
   as "NDC-{constituency abbreviation}-{zero-padded sequential number}").
   Immediately after a successful insert, request device GPS location
   (geolocator, with a clear permission-rationale dialog) and call
   POST /api/members/:id/capture-metadata on the Railway backend with the
   {lat, lng} — that endpoint fills in registration_ip server-side. If this
   call fails (e.g. offline), don't block the registration — the member row
   already exists as pending; retry capture-metadata silently next time the
   app is online.
4. "My Submissions": paginated (Supabase .range(), never fetch-all), filter
   by status, tap for detail (read-only once status leaves pending — the
   backend trigger already enforces this, but the UI should reflect it too
   rather than showing an editable form that will just error).
5. Offline queue: if there's no connection at submit time, queue the
   registration locally (Hive) and sync when back online — simple queue,
   don't over-engineer retry logic.

Skeleton loaders for lists, not spinners. Use the UI-UX Pro Max skill
throughout. Walk me through the flow, then wait for confirmation before Phase 3.
```

### Phase 3 — Higher Authority: Review, Directory, Dashboard

```
Build the Higher Authority role's screens.

1. Dashboard: metric cards (total members, pending count, breakdown by
   region/constituency, membership type distribution) with fl_chart styled
   in NDC colors, not default chart theming.
2. Review queue: paginated list of status='pending' members. Tap for full
   detail — photo (via signed URL, createSignedUrl with ~1hr expiry, cached
   for the session), geolocation shown on a small map preview, submission
   metadata. Approve sets status='active', reviewed_by=current user. Reject
   requires a reason (stored in rejection_reason) and sets status='rejected'.
   These are simple UPDATE calls via the Supabase SDK — RLS + the trigger
   already restrict higher_authority to only touching status/reviewed_by/
   rejection_reason, so no extra client-side enforcement needed beyond
   catching and displaying the Postgres error if it somehow fires.
3. Member directory: paginated, server-side searchable (name via the
   full-text index, phone, member_number) and filterable (region, district,
   constituency, membership_type, status). Must use Supabase range queries
   with debounced search — never fetch-all-then-filter-client-side.
4. Member detail (read-only, shows status history from audit_log for that
   member — query audit_log where target_table='members' and target_id=
   the member's id).
5. Export: call POST /api/exports/members on the Railway backend with the
   current filter state, rather than generating large exports on-device.

Use the UI-UX Pro Max skill, especially for the chart-heavy dashboard.
Wait for confirmation before Phase 4.
```

### Phase 4 — Admin: Operator & System Management

```
Build the Admin role's screens. Every write in this phase that touches
app_users role/is_active/account creation goes through the Railway backend
endpoints (Section 5) — the app never creates Supabase Auth users directly
from the client.

1. Operator management: paginated list of app_users. "Create Operator" calls
   POST /api/admin/operators (full_name, email, role). Suspend/reactivate
   call the corresponding Railway endpoints. Role changes also go through
   the backend (add a PATCH-style endpoint if needed — same pattern as
   suspend/reactivate, admin-only, service role).
2. Lookup table management: CRUD for regions/districts/constituencies/
   polling_stations, enforcing the cascading relationships already defined
   in the schema (can't create a district without picking its region, etc.).
   These CAN go through the Supabase client SDK directly since RLS already
   restricts writes to admin.
3. Audit log viewer: paginated, filterable by actor/action/date range,
   read-only. Make this feel trustworthy and clear — it's a compliance
   feature, not an afterthought table dump.
4. System overview: aggregate stats across the whole system.

Use the UI-UX Pro Max skill. Wait for confirmation before Phase 5.
```

### Phase 5 — Polish & Scale Pass

```
Full pass for 100k+ member records:

1. Audit every list/query in the app — confirm each uses .range() pagination,
   flag and fix any that don't.
2. Cross-check every WHERE/ORDER BY clause used across the app's queries
   against the indexes in Section 2 — add any that are missing.
3. cached_network_image (or equivalent for signed URLs, since they expire —
   cache the image bytes, not just the URL) for all member photos, with a
   deliberate Phosphor placeholder/error state.
4. Review every loading/empty/error state — replace generic ones with
   something intentional and on-brand.
5. Pull-to-refresh with the Lottie animation on all list screens.
6. Verify offline handling works beyond just registration (Phase 2) —
   directory/dashboard should degrade gracefully, not crash, with no connection.
7. Accessibility: contrast against NDC green/red backgrounds, readable font
   sizes, adequate tap targets.

Report what you found and fixed. Wait for confirmation before Phase 6.
```

### Phase 6 — Android Release Build

```
1. App name "Vanguard", package com.ndc.vanguard, NDC-branded icon (ask me
   for the actual logo file before finalizing — use a brand-color placeholder
   until then).
2. Configure release signing: generate a keystore, explain what I need to
   keep safe, wire signing config into android/app/build.gradle.
3. Set versionCode/versionName, enable minification/resource shrinking for release.
4. Run `flutter build apk --release`, confirm the output path.
5. Final checklist: no secrets committed, confirm RLS is active (not
   permissive defaults) by attempting a cross-role query and expecting it to
   fail, confirm the service_role key exists only in the Railway server's
   environment and nowhere in the Flutter app.

Give me the APK path and a short v1-vs-deferred summary.
```

---

## 9. Still Worth Confirming With Your Client

- Official NDC logo file (vector) for the app icon/splash and to get exact brand hex.
- Any data-residency requirement for member PII (DOB, phone, geolocation) — affects which Supabase/Railway region you provision in.
- Real field connectivity conditions for personnel doing registrations, to sanity-check the offline queue behavior in Phase 2.

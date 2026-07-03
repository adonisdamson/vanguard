-- gen_random_uuid() requires pgcrypto (enabled by default in Supabase)
-- If running on a vanilla Postgres instance, uncomment the next line:
-- create extension if not exists pgcrypto;

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

-- 0010_member_fields.sql
-- Add fields required to match the NDC Tema West register PDF exactly.

alter table members add column if not exists other_party    text;
alter table members add column if not exists party_position text;

-- Generated stored column — always in sync, never stale
alter table members add column if not exists full_name text
  generated always as (trim(first_name || ' ' || last_name)) stored;

-- Trigram index on the stored full_name for fast ILIKE search
create index if not exists idx_members_fullname_trgm
  on members using gin (full_name gin_trgm_ops);

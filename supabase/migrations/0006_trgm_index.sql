-- Enable pg_trgm for trigram-based ILIKE on member names
-- Required so that 'first_name ILIKE %query%' uses a GIN index instead of a seq-scan.
-- Phone and member_number use prefix-only ILIKE (no leading %) so they hit the existing btree
-- indexes (idx_members_phone, idx_members_member_number) without this extension.
create extension if not exists pg_trgm;

-- Drop the old expression-based GIN index (tsvector — unused by any current query)
drop index if exists idx_members_name_search;

-- Trigram index covering the concatenated name — used by ILIKE '%term%' queries
create index idx_members_name_trgm on members
  using gin ((first_name || ' ' || last_name) gin_trgm_ops);

-- Prefix-search support for phone and member_number already covered by:
--   idx_members_phone         on members(phone)
--   idx_members_member_number on members(member_number)
-- No changes needed there — the queries are updated to use prefix-only ILIKE (s%).

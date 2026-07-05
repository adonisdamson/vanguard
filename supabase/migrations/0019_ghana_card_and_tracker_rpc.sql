-- 0019_ghana_card_and_tracker_rpc.sql
-- Add Ghana Card / Voter ID field + electoral area tracker RPC

-- Ghana Card ID column on members (sensitive PII — RLS already guards members)
alter table members add column if not exists ghana_card_id text;
create index if not exists idx_members_ghana_card_id on members(ghana_card_id) where ghana_card_id is not null;

-- Electoral area tracker: count total and approved members per electoral area
create or replace function public.get_electoral_area_stats()
returns table(electoral_area int, total bigint, active_count bigint)
language sql stable security definer as $$
  select
    ps.electoral_area,
    count(m.id) as total,
    count(m.id) filter (where m.status = 'active') as active_count
  from polling_stations ps
  left join members m on m.polling_station_id = ps.id
  where ps.electoral_area is not null
  group by ps.electoral_area
  order by ps.electoral_area;
$$;

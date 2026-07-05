-- 0020_polling_station_stats.sql
-- Per-polling-station registration stats for the Area Tracker.
-- The previous get_electoral_area_stats() grouped by the bare integer
-- electoral_area (1..11), which is meaningless to coordinators. This returns
-- one row per real polling station (code + name), still carrying its
-- electoral_area so the client can group under an area header.

create or replace function public.get_polling_station_stats()
returns table(
  polling_station_id int,
  station_code text,
  name text,
  electoral_area int,
  total bigint,
  active_count bigint
)
language sql stable security definer as $$
  select
    ps.id,
    ps.station_code,
    ps.name,
    ps.electoral_area,
    count(m.id) as total,
    count(m.id) filter (where m.status = 'active') as active_count
  from polling_stations ps
  left join members m on m.polling_station_id = ps.id
  group by ps.id, ps.station_code, ps.name, ps.electoral_area
  order by ps.electoral_area nulls last, ps.station_code;
$$;

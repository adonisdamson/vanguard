-- 0014_fix_polling_station_uniqueness.sql
-- The EC list has multiple polling stations with the same name at the same
-- constituency (A/B hall splits). station_code is the true unique identifier.
-- Drop the name-level unique constraint; station_code unique already enforces it.

alter table polling_stations drop constraint if exists polling_stations_constituency_id_name_key;

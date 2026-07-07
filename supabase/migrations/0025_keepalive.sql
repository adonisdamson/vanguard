-- 0025_keepalive.sql — anti-pause heartbeat for the free-tier project.
--
-- Free Supabase projects pause after 7 days of no database activity. This
-- tiny function is called on a schedule (GitHub Actions, every 2 days) so a
-- real query hits Postgres and resets the inactivity timer — without adding
-- any data. SECURITY DEFINER + granted to anon so the ping needs no login
-- and is never filtered by RLS.
create or replace function public.keepalive()
returns timestamptz
language sql
security definer
set search_path = public
as $$
  select now();
$$;

grant execute on function public.keepalive() to anon, authenticated;

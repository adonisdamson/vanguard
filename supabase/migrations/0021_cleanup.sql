-- 0021_cleanup.sql — B9 database audit: drop superseded/dead objects.
--
-- Audit method: remote migration history matches local 0001–0020 exactly
-- (supabase migration list --linked), so the files are the object inventory.
-- Everything below is verified unreferenced by the app (lib/) and server.

-- 1) Tracker RPC superseded: 0019's get_electoral_area_stats returned bare
--    integer area buckets; 0020's get_polling_station_stats (real station
--    names + EC codes) replaced it and is what the app calls. No references
--    to the old function remain in lib/ or server/.
drop function if exists public.get_electoral_area_stats();

-- 2) Founding-admin bootstrap (0007, patched 0016): auto-promoted one
--    hardcoded email to admin at signup. That account exists and is active,
--    and the request-access approval flow is now the only account path.
--    Dropping it also leaves exactly ONE trigger on auth.users
--    (on_auth_user_created -> handle_new_user, 0018 version), per the
--    account-model spec.
drop trigger if exists trg_bootstrap_admin on auth.users;
drop function if exists public.bootstrap_admin_on_signup();

-- 0018_fault_tolerant_signup.sql
--
-- Root cause of recurring "Database error saving new user" 500s:
--   When a prior signup attempt fails mid-way (e.g. the auth.users INSERT
--   was rolled back by the failing trigger), the email can end up in
--   app_users from a prior code path with a DIFFERENT id, or simply the
--   unique email constraint fires on a subsequent attempt for the same address.
--   0017 fixed the role-cast failure but did not handle unique_violation on email.
--
-- This migration makes the trigger fully fault-tolerant:
--   - Catches unique_violation (email duplicate) as well as role cast errors.
--   - Also deletes any orphaned app_users rows not present in auth.users.

-- Replace the trigger function with a version that handles all failure modes
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role user_role;
BEGIN
  -- Safe role cast: bad/unknown value → NULL, never throws
  BEGIN
    v_role := nullif(new.raw_user_meta_data->>'requested_role', '')::user_role;
  EXCEPTION WHEN others THEN
    v_role := null;
  END;

  -- Safe insert: handle both id conflicts (idempotent retries) and email
  -- uniqueness conflicts (stale rows from previous partial signups).
  BEGIN
    INSERT INTO public.app_users (id, full_name, email, role, is_active, signup_source, requested_role)
    VALUES (
      new.id,
      coalesce(new.raw_user_meta_data->>'full_name', ''),
      new.email,
      null,
      false,
      'self',
      v_role
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN unique_violation THEN
    -- email already exists with a different id (orphaned row from a prior
    -- failed attempt). Delete the stale row and retry once.
    DELETE FROM public.app_users WHERE email = new.email AND id <> new.id;
    INSERT INTO public.app_users (id, full_name, email, role, is_active, signup_source, requested_role)
    VALUES (
      new.id,
      coalesce(new.raw_user_meta_data->>'full_name', ''),
      new.email,
      null,
      false,
      'self',
      v_role
    )
    ON CONFLICT (id) DO NOTHING;
  END;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Clean up any pre-existing orphaned rows (no matching auth.users entry)
-- that could cause the email unique violation for legitimate retries.
-- The bootstrap admin email is excluded as a safety guard.
DELETE FROM public.app_users au
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users u WHERE u.id = au.id
)
AND lower(au.email) <> 'adonisdamson@gmail.com';

SELECT 'handle_new_user trigger hardened — email unique_violation now handled' AS result;

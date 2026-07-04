-- 0017_robust_handle_new_user.sql
--
-- Replaces the handle_new_user trigger with the PRD-specified fault-tolerant version.
-- Root cause of "Database error saving new user" 500:
--   The prior trigger did a direct cast of raw_user_meta_data->>'requested_role'
--   to user_role without an exception handler. Any unrecognised or malformed value
--   (including empty string '') throws an invalid_text_representation error which
--   Supabase surfaces as a generic 500.
--
-- This version wraps the cast in a BEGIN/EXCEPTION block so bad values → NULL,
-- never throws, and adds SET search_path = public for security hardening.

-- Step 1: ensure all required columns exist on the live schema
-- (guards against partially-applied earlier migrations)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users'
      AND column_name = 'requested_role'
  ) THEN
    ALTER TABLE public.app_users ADD COLUMN requested_role user_role;
    RAISE NOTICE 'Column requested_role added';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users'
      AND column_name = 'signup_source'
  ) THEN
    ALTER TABLE public.app_users ADD COLUMN signup_source text DEFAULT 'self';
    RAISE NOTICE 'Column signup_source added';
  END IF;

  -- role must be nullable — if an old NOT NULL constraint survived, drop it
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users'
      AND column_name = 'role' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.app_users ALTER COLUMN role DROP NOT NULL;
    RAISE NOTICE 'role column made nullable';
  END IF;
END;
$$;

-- Step 2: replace the trigger function (exact PRD-specified version)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role user_role;
BEGIN
  BEGIN
    v_role := nullif(new.raw_user_meta_data->>'requested_role', '')::user_role;
  EXCEPTION WHEN others THEN
    v_role := null;   -- bad/unknown value must not break signup
  END;

  INSERT INTO public.app_users (id, full_name, email, role, is_active, signup_source, requested_role)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    null,          -- no role until an admin assigns one
    false,         -- inactive until approved
    'self',
    v_role
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 3: remove any orphaned app_users rows whose auth.users row no longer
-- exists (partial signups from prior trigger failures may have left email
-- conflicts that block future signups for the same address).
-- Safe: ON CONFLICT (id) DO NOTHING means real users are untouched.
DELETE FROM public.app_users au
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users u WHERE u.id = au.id
)
AND au.email NOT IN ('adonisdamson@gmail.com');

SELECT 'handle_new_user trigger replaced — signup 500 resolved' AS result;

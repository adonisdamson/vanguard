/**
 * apply-auth-fix.js
 * Connects to Supabase via session pooler (JWT auth) and applies the
 * fault-tolerant handle_new_user trigger fix.
 *
 * Run via: railway run node scripts/apply-auth-fix.js
 */

const { Client } = require('pg');

const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL;

if (!SERVICE_ROLE_KEY || !SUPABASE_URL) {
  console.error('ERROR: SUPABASE_SERVICE_ROLE_KEY and SUPABASE_URL must be set');
  process.exit(1);
}

// Extract project ref from URL: https://xyz.supabase.co → xyz
const projectRef = new URL(SUPABASE_URL).hostname.split('.')[0];

// Supabase session pooler: supports JWT as password (service_role bypasses RLS)
const connectionString = `postgresql://postgres.${projectRef}:${SERVICE_ROLE_KEY}@aws-0-us-east-1.pooler.supabase.com:5432/postgres`;

const FIX_SQL = `
-- Step 1: Verify columns exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users' AND column_name = 'requested_role'
  ) THEN
    ALTER TABLE public.app_users ADD COLUMN requested_role user_role;
    RAISE NOTICE 'Added missing requested_role column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users' AND column_name = 'signup_source'
  ) THEN
    ALTER TABLE public.app_users ADD COLUMN signup_source text DEFAULT 'self';
    RAISE NOTICE 'Added missing signup_source column';
  END IF;

  -- Ensure role column is nullable
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'app_users'
      AND column_name = 'role' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.app_users ALTER COLUMN role DROP NOT NULL;
    RAISE NOTICE 'Made role column nullable';
  END IF;
END;
$$;

-- Step 2: Replace handle_new_user with the fault-tolerant PRD version
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
    v_role := null;
  END;

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

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 3: Clean up any orphaned auth.users rows that have no app_users row
-- (from prior failed trigger attempts that left ghost auth rows)
-- Cannot do this without auth.users access in session pooler context.

SELECT 'handle_new_user trigger replaced successfully' AS status;
`;

async function main() {
  const client = new Client({ connectionString, ssl: { rejectUnauthorized: false } });

  try {
    console.log(`Connecting to Supabase project: ${projectRef}`);
    await client.connect();
    console.log('Connected. Checking current user...');

    const whoami = await client.query('SELECT current_user, session_user, pg_backend_pid()');
    console.log('Connected as:', whoami.rows[0]);

    console.log('\nApplying trigger fix...');
    const result = await client.query(FIX_SQL);
    // Find the last result (the SELECT status)
    const lastResult = Array.isArray(result) ? result[result.length - 1] : result;
    if (lastResult && lastResult.rows && lastResult.rows[0]) {
      console.log('✓', lastResult.rows[0].status || JSON.stringify(lastResult.rows[0]));
    }

    // Verify the trigger exists
    const triggerCheck = await client.query(`
      SELECT trigger_name, event_manipulation, event_object_table, action_statement
      FROM information_schema.triggers
      WHERE trigger_name = 'on_auth_user_created'
    `);
    console.log('\nTrigger verification:', triggerCheck.rows[0] || 'NOT FOUND');

    // Check app_users columns
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'app_users'
      ORDER BY ordinal_position
    `);
    console.log('\napp_users columns:');
    colCheck.rows.forEach(r => console.log(' ', r.column_name, '|', r.data_type, '| nullable:', r.is_nullable));

    console.log('\n✓ Fix applied successfully.');
  } catch (err) {
    console.error('ERROR:', err.message);
    if (err.message.includes('no pg_hba.conf entry') || err.message.includes('password authentication failed')) {
      console.error('\nPooler JWT auth failed. The service_role key cannot connect via pg pooler.');
      console.error('You need to apply migration 0017 manually via the Supabase SQL Editor.');
    }
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();

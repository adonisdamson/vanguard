const express = require('express');
const router = express.Router();
const { Client } = require('pg');

// All migrations as embedded strings — applied in order, idempotent.
// Protected by BOOTSTRAP_SECRET so this endpoint cannot be called without it.

const MIGRATIONS = [
  {
    id: '0001_schema',
    sql: `
      create type if not exists user_role as enum ('admin', 'higher_authority', 'personnel');
      create type if not exists member_status as enum ('pending', 'active', 'rejected', 'suspended');
      create type if not exists membership_type as enum ('youth_member', 'adult_member', 'volunteer', 'executive', 'administration');
      create type if not exists preferred_role as enum ('campaigning', 'events', 'media', 'fundraising');
    `,
    description: 'Ensure enums exist',
  },
  {
    id: '0008_columns',
    sql: `
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='app_users' AND column_name='requested_role')
        THEN ALTER TABLE public.app_users ADD COLUMN requested_role user_role; END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='app_users' AND column_name='signup_source')
        THEN ALTER TABLE public.app_users ADD COLUMN signup_source text DEFAULT 'self'; END IF;

        IF EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='app_users'
            AND column_name='role' AND is_nullable='NO')
        THEN ALTER TABLE public.app_users ALTER COLUMN role DROP NOT NULL; END IF;

        ALTER TABLE public.app_users ALTER COLUMN is_active SET DEFAULT false;
      END $$;
    `,
    description: 'Ensure app_users columns (0008)',
  },
  {
    id: '0016_fix_bootstrap_trigger',
    sql: `
      CREATE OR REPLACE FUNCTION public.bootstrap_admin_on_signup()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
      BEGIN
        IF lower(new.email) = 'adonisdamson@gmail.com' THEN
          INSERT INTO public.app_users (id, full_name, email, role, is_active, created_at)
          VALUES (new.id, 'Adonis Damson', new.email, 'admin', true, now())
          ON CONFLICT (id) DO UPDATE SET role = 'admin', is_active = true;
        END IF;
        RETURN new;
      END;
      $$;

      DROP TRIGGER IF EXISTS trg_bootstrap_admin ON auth.users;
      CREATE TRIGGER trg_bootstrap_admin
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION public.bootstrap_admin_on_signup();

      UPDATE public.app_users au
      SET role = 'admin', is_active = true
      FROM auth.users au2
      WHERE au.id = au2.id
        AND lower(au2.email) = 'adonisdamson@gmail.com'
        AND (au.role IS NULL OR au.is_active = false);
    `,
    description: 'Fix bootstrap admin trigger (0016)',
  },
  {
    id: '0017_robust_handle_new_user',
    sql: `
      CREATE OR REPLACE FUNCTION public.handle_new_user()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
      DECLARE v_role user_role;
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
          null, false, 'self', v_role
        )
        ON CONFLICT (id) DO NOTHING;

        RETURN new;
      END;
      $$;

      DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
      CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION handle_new_user();

      DELETE FROM public.app_users au
      WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = au.id)
        AND au.email NOT IN ('adonisdamson@gmail.com');
    `,
    description: 'Fault-tolerant handle_new_user (0017)',
  },
];

function makeClient() {
  const ref = new URL(process.env.SUPABASE_URL).hostname.split('.')[0];
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  // Try JWT-based auth on the direct DB host (Railway has IPv6)
  return new Client({
    host: `db.${ref}.supabase.co`,
    port: 5432,
    database: 'postgres',
    user: `postgres.${ref}`,
    password: key,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  });
}

// POST /api/internal/run-migrations
router.post('/', async (req, res) => {
  const secret = req.headers['x-bootstrap-secret'] || req.body.secret;
  if (!secret || secret !== process.env.BOOTSTRAP_SECRET) {
    return res.status(403).json({ error: 'Invalid secret' });
  }

  const client = makeClient();
  const results = [];

  try {
    await client.connect();
    results.push({ step: 'connect', ok: true, user: (await client.query('SELECT current_user')).rows[0] });

    for (const m of MIGRATIONS) {
      try {
        await client.query(m.sql);
        results.push({ step: m.id, ok: true, desc: m.description });
      } catch (err) {
        results.push({ step: m.id, ok: false, error: err.message, desc: m.description });
        // Continue — some steps may fail if already applied
      }
    }

    res.json({ ok: true, results });
  } catch (err) {
    res.status(500).json({ ok: false, connectError: err.message, results });
  } finally {
    try { await client.end(); } catch (_) {}
  }
});

module.exports = router;

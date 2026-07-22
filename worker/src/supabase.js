import { createClient } from '@supabase/supabase-js';

// Workers have no persistent process, so clients are built per-request from the
// binding env rather than cached in module scope. createClient is cheap — it
// just holds config; the actual work is fetch calls.

export function anonClient(env) {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function serviceClient(env) {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

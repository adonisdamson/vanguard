const { createClient } = require('@supabase/supabase-js');

let _anonClient = null;
let _serviceClient = null;

function anonClient() {
  if (!_anonClient) {
    _anonClient = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY
    );
  }
  return _anonClient;
}

function serviceClient() {
  if (!_serviceClient) {
    _serviceClient = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );
  }
  return _serviceClient;
}

module.exports = { anonClient, serviceClient };

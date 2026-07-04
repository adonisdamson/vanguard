const express = require('express');
const router = express.Router();
const { serviceClient } = require('../supabase');

const ADMIN_EMAIL = 'adonisdamson@gmail.com';

// POST /api/admin/bootstrap-superadmin
// Creates or resets the first admin account — no JWT needed, protected by BOOTSTRAP_SECRET.
// Call once after deploy. Safe to call repeatedly (idempotent).
router.post('/', async (req, res) => {
  const secret = req.headers['x-bootstrap-secret'] || req.body.secret;
  if (!secret || secret !== process.env.BOOTSTRAP_SECRET) {
    return res.status(403).json({ error: 'Invalid bootstrap secret' });
  }

  const { password } = req.body;
  if (!password || password.length < 8) {
    return res.status(400).json({ error: 'password required (min 8 chars)' });
  }

  const sc = serviceClient();

  // Find existing Supabase Auth user for the admin email
  const { data: listData, error: listError } = await sc.auth.admin.listUsers({ perPage: 1000 });
  if (listError) return res.status(500).json({ error: listError.message });

  const existing = listData.users.find(u => u.email?.toLowerCase() === ADMIN_EMAIL);
  let userId;

  if (existing) {
    // Reset password + confirm email
    const { error } = await sc.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
    });
    if (error) return res.status(500).json({ error: error.message });
    userId = existing.id;
  } else {
    // Create brand-new auth user
    const { data: created, error } = await sc.auth.admin.createUser({
      email: ADMIN_EMAIL,
      password,
      email_confirm: true,
    });
    if (error) return res.status(500).json({ error: error.message });
    userId = created.user.id;
  }

  // Upsert app_users row with admin role — overrides any broken pending row
  const { error: upsertError } = await sc.from('app_users').upsert(
    { id: userId, full_name: 'Adonis Damson', email: ADMIN_EMAIL, role: 'admin', is_active: true },
    { onConflict: 'id' }
  );
  if (upsertError) return res.status(500).json({ error: upsertError.message });

  res.json({ ok: true, userId, message: 'Admin account ready — you can now log in.' });
});

module.exports = router;

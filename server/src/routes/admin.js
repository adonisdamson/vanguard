const express = require('express');
const router = express.Router();
const { requireRole } = require('../auth');
const { serviceClient } = require('../supabase');

// POST /api/admin/operators — creates Supabase Auth user + app_users row. Admin only.
router.post('/', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  const { full_name, email, role, phone, password,
          assigned_region_id, assigned_district_id, assigned_constituency_id } = req.body;
  if (!full_name || !email || !role) {
    return res.status(400).json({ error: 'full_name, email, and role are required' });
  }

  // Two creation modes:
  // - password provided → ready-to-use account (email pre-confirmed, operator
  //   signs in immediately). Primary path: an invited user has NO password
  //   until they click the emailed link, so if that email never lands the
  //   account is unusable — unacceptable in the field.
  // - no password → legacy invite-email flow.
  // Either way the handle_new_user trigger creates the app_users row
  // (role=null, is_active=false); the upsert below sets role + activation.
  let userId;
  if (password) {
    if (String(password).length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }
    const { data: created, error: createError } = await serviceClient().auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, signup_source: 'admin_created' },
    });
    if (createError) {
      return res.status(400).json({ error: createError.message });
    }
    userId = created.user.id;
  } else {
    const { data: inviteData, error: inviteError } = await serviceClient().auth.admin.inviteUserByEmail(email, {
      data: { full_name, signup_source: 'admin_created' },
    });
    if (inviteError) {
      return res.status(400).json({ error: inviteError.message });
    }
    userId = inviteData.user.id;
  }

  const { error: upsertError } = await serviceClient().from('app_users').upsert({
    id: userId,
    full_name,
    email,
    phone: phone || null,
    role,
    is_active: true,
    created_by: ctx.user.id,
    assigned_region_id: assigned_region_id || null,
    assigned_district_id: assigned_district_id || null,
    assigned_constituency_id: assigned_constituency_id || null,
  }, { onConflict: 'id' });

  if (upsertError) {
    await serviceClient().auth.admin.deleteUser(userId);
    return res.status(500).json({ error: upsertError.message });
  }

  res.status(201).json({ id: userId });
});

// POST /api/admin/operators/:id/suspend
router.post('/:id/suspend', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  const { error } = await serviceClient()
    .from('app_users')
    .update({ is_active: false })
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// POST /api/admin/operators/:id/reactivate
router.post('/:id/reactivate', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  const { error } = await serviceClient()
    .from('app_users')
    .update({ is_active: true })
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// POST /api/admin/operators/:id/role
router.post('/:id/role', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  const { role } = req.body;
  if (!role) return res.status(400).json({ error: 'role is required' });

  const { error } = await serviceClient()
    .from('app_users')
    .update({ role })
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// POST /api/admin/operators/:id/approve — approve a self-signup: set role + activate
router.post('/:id/approve', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  const { role, assigned_region_id, assigned_district_id, assigned_constituency_id } = req.body;
  if (!role) return res.status(400).json({ error: 'role is required' });

  const { error } = await serviceClient()
    .from('app_users')
    .update({
      role,
      is_active: true,
      assigned_region_id: assigned_region_id || null,
      assigned_district_id: assigned_district_id || null,
      assigned_constituency_id: assigned_constituency_id || null,
    })
    .eq('id', req.params.id)
    .is('role', null); // only approve pending (role-less) users

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// POST /api/admin/operators/:id/decline — reject a self-signup: delete auth user + row
router.post('/:id/decline', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin']);
  if (!ctx) return;

  // Delete app_users row first (FK cascade would handle this too, but be explicit)
  const { error: rowError } = await serviceClient()
    .from('app_users')
    .delete()
    .eq('id', req.params.id)
    .is('role', null); // safety: only decline pending users

  if (rowError) return res.status(500).json({ error: rowError.message });

  // Delete the auth user so they can re-register with the same email later
  const { error: authError } = await serviceClient().auth.admin.deleteUser(req.params.id);
  if (authError) console.warn('Could not delete auth user:', authError.message);

  res.json({ ok: true });
});

module.exports = router;

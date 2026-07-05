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

  // inviteUserByEmail creates the auth user AND sends an invitation email automatically.
  // The handle_new_user trigger creates the app_users row (role=null, is_active=false);
  // we then upsert to set the correct role and activate the account.
  const { data: inviteData, error: inviteError } = await serviceClient().auth.admin.inviteUserByEmail(email, {
    data: { full_name, signup_source: 'admin_created' },
  });

  if (inviteError) {
    return res.status(400).json({ error: inviteError.message });
  }

  const userId = inviteData.user.id;

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

import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requireRole } from '../auth.js';
import { serviceClient } from '../supabase.js';

const admin = new Hono();

const VALID_ROLES = new Set(['admin', 'higher_authority', 'personnel']);

// POST /api/admin/operators — creates Supabase Auth user + app_users row. Admin only.
admin.post('/', async (c) => {
  const ctx = await requireRole(c, ['admin']);
  const svc = serviceClient(c.env);

  const { full_name, email, role, phone, password, party_position, branch,
          assigned_region_id, assigned_district_id, assigned_constituency_id } =
    await c.req.json().catch(() => ({}));
  if (!full_name || !email || !role) {
    throw new HTTPException(400, { message: 'full_name, email, and role are required' });
  }
  if (!VALID_ROLES.has(role)) {
    throw new HTTPException(400, { message: `Invalid role. Must be one of: ${[...VALID_ROLES].join(', ')}` });
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
      throw new HTTPException(400, { message: 'Password must be at least 8 characters' });
    }
    const { data: created, error: createError } = await svc.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, signup_source: 'admin_created' },
    });
    if (createError) {
      throw new HTTPException(400, { message: createError.message });
    }
    userId = created.user.id;
  } else {
    const { data: inviteData, error: inviteError } =
      await svc.auth.admin.inviteUserByEmail(email, {
        data: { full_name, signup_source: 'admin_created' },
      });
    if (inviteError) {
      throw new HTTPException(400, { message: inviteError.message });
    }
    userId = inviteData.user.id;
  }

  const { error: upsertError } = await svc.from('app_users').upsert({
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
    party_position: party_position || null,
    branch: branch || null,
    // Admin-chosen password → force the operator to set their own on first
    // sign-in. Invite flow (no password here) sets their own from the link.
    must_change_password: password ? true : false,
  }, { onConflict: 'id' });

  if (upsertError) {
    await svc.auth.admin.deleteUser(userId);
    throw new HTTPException(500, { message: upsertError.message });
  }

  return c.json({ id: userId }, 201);
});

// POST /api/admin/operators/:id/suspend
admin.post('/:id/suspend', async (c) => {
  await requireRole(c, ['admin']);
  const { error } = await serviceClient(c.env)
    .from('app_users')
    .update({ is_active: false })
    .eq('id', c.req.param('id'));
  if (error) throw new HTTPException(500, { message: error.message });
  return c.json({ ok: true });
});

// POST /api/admin/operators/:id/reactivate
admin.post('/:id/reactivate', async (c) => {
  await requireRole(c, ['admin']);
  const { error } = await serviceClient(c.env)
    .from('app_users')
    .update({ is_active: true })
    .eq('id', c.req.param('id'));
  if (error) throw new HTTPException(500, { message: error.message });
  return c.json({ ok: true });
});

// POST /api/admin/operators/:id/role
admin.post('/:id/role', async (c) => {
  await requireRole(c, ['admin']);
  const { role } = await c.req.json().catch(() => ({}));
  if (!role) throw new HTTPException(400, { message: 'role is required' });
  if (!VALID_ROLES.has(role)) {
    throw new HTTPException(400, { message: `Invalid role. Must be one of: ${[...VALID_ROLES].join(', ')}` });
  }
  const svc = serviceClient(c.env);
  const id = c.req.param('id');

  // higher_authority accounts are protected — their role cannot be changed.
  const { data: target } = await svc.from('app_users').select('role').eq('id', id).single();
  if (target?.role === 'higher_authority') {
    throw new HTTPException(403, { message: 'The role of a Higher Authority account cannot be changed.' });
  }

  const { error } = await svc.from('app_users').update({ role }).eq('id', id);
  if (error) throw new HTTPException(500, { message: error.message });
  return c.json({ ok: true });
});

// POST /api/admin/operators/:id/password — admin sets a new password for any
// operator, entirely in-app (no reset emails, which proved undeliverable in
// the field). The admin shares the new password with the operator securely.
admin.post('/:id/password', async (c) => {
  const ctx = await requireRole(c, ['admin']);
  const svc = serviceClient(c.env);
  const id = c.req.param('id');

  const { password } = await c.req.json().catch(() => ({}));
  if (!password || String(password).length < 8) {
    throw new HTTPException(400, { message: 'Password must be at least 8 characters' });
  }

  const { error } = await svc.auth.admin.updateUserById(id, { password });
  if (error) throw new HTTPException(400, { message: error.message });

  // Force the operator to replace this admin-known password on next sign-in.
  await svc.from('app_users').update({ must_change_password: true }).eq('id', id);

  // Audit the reset. The service key has no auth.uid(), so the audit RPC/trigger
  // path can't attribute it — write the row directly with the acting admin.
  await svc.from('audit_log').insert({
    actor_id: ctx.user.id,
    action: 'operator_password_reset',
    target_table: 'app_users',
    target_id: id,
    metadata: {},
  });

  return c.json({ ok: true });
});

// POST /api/admin/operators/:id/approve — approve a self-signup: set role + activate
admin.post('/:id/approve', async (c) => {
  await requireRole(c, ['admin']);
  const { role, assigned_region_id, assigned_district_id, assigned_constituency_id } =
    await c.req.json().catch(() => ({}));
  if (!role) throw new HTTPException(400, { message: 'role is required' });
  if (!VALID_ROLES.has(role)) {
    throw new HTTPException(400, { message: `Invalid role. Must be one of: ${[...VALID_ROLES].join(', ')}` });
  }

  const { error } = await serviceClient(c.env)
    .from('app_users')
    .update({
      role,
      is_active: true,
      assigned_region_id: assigned_region_id || null,
      assigned_district_id: assigned_district_id || null,
      assigned_constituency_id: assigned_constituency_id || null,
    })
    .eq('id', c.req.param('id'))
    .is('role', null); // only approve pending (role-less) users

  if (error) throw new HTTPException(500, { message: error.message });
  return c.json({ ok: true });
});

// POST /api/admin/operators/:id/decline — reject a self-signup: delete auth user + row
admin.post('/:id/decline', async (c) => {
  await requireRole(c, ['admin']);
  const svc = serviceClient(c.env);
  const id = c.req.param('id');

  // Delete app_users row first (FK cascade would handle this too, but be explicit)
  const { error: rowError } = await svc
    .from('app_users')
    .delete()
    .eq('id', id)
    .is('role', null); // safety: only decline pending users
  if (rowError) throw new HTTPException(500, { message: rowError.message });

  // Delete the auth user so they can re-register with the same email later
  const { error: authError } = await svc.auth.admin.deleteUser(id);
  if (authError) console.warn('Could not delete auth user:', authError.message);

  return c.json({ ok: true });
});

export default admin;

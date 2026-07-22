import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requireAuth } from '../auth.js';
import { serviceClient } from '../supabase.js';

const members = new Hono();

// POST /api/members/:id/capture-metadata
// Any authenticated operator who owns the record.
// Reads the real client IP from Cloudflare, accepts {lat, lng}, writes both to
// the member row. On Workers the true edge IP is CF-Connecting-IP — more
// reliable than parsing x-forwarded-for behind a proxy.
members.post('/:id/capture-metadata', async (c) => {
  const user = await requireAuth(c);

  const memberId = c.req.param('id');
  const { lat, lng } = await c.req.json().catch(() => ({}));

  const svc = serviceClient(c.env);
  const { data: member, error: fetchError } = await svc
    .from('members')
    .select('id, registered_by')
    .eq('id', memberId)
    .single();

  if (fetchError || !member) {
    throw new HTTPException(404, { message: 'Member not found' });
  }
  if (member.registered_by !== user.id) {
    throw new HTTPException(403, { message: 'You did not register this member' });
  }

  const ip =
    c.req.header('cf-connecting-ip') ||
    (c.req.header('x-forwarded-for') || '').split(',')[0].trim() ||
    null;

  const updatePayload = { registration_ip: ip };
  if (lat != null && lng != null) {
    updatePayload.registration_geolocation = `(${lng},${lat})`;
  }

  const { error: updateError } = await svc
    .from('members')
    .update(updatePayload)
    .eq('id', memberId);

  if (updateError) {
    throw new HTTPException(500, { message: updateError.message });
  }

  return c.json({ ok: true });
});

export default members;

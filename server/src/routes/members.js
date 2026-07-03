const express = require('express');
const router = express.Router();
const { requireAuth } = require('../auth');
const { serviceClient } = require('../supabase');

// POST /api/members/:id/capture-metadata
// Any authenticated operator who owns the record.
// Reads real IP from x-forwarded-for, accepts {lat, lng}, writes to the member row.
router.post('/:id/capture-metadata', async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;

  const memberId = req.params.id;
  const { lat, lng } = req.body;

  const { data: member, error: fetchError } = await serviceClient()
    .from('members')
    .select('id, registered_by')
    .eq('id', memberId)
    .single();

  if (fetchError || !member) {
    return res.status(404).json({ error: 'Member not found' });
  }
  if (member.registered_by !== user.id) {
    return res.status(403).json({ error: 'You did not register this member' });
  }

  const ip =
    (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
    req.socket.remoteAddress;

  const updatePayload = { registration_ip: ip };
  if (lat != null && lng != null) {
    updatePayload.registration_geolocation = `(${lng},${lat})`;
  }

  const { error: updateError } = await serviceClient()
    .from('members')
    .update(updatePayload)
    .eq('id', memberId);

  if (updateError) {
    return res.status(500).json({ error: updateError.message });
  }

  res.json({ ok: true });
});

module.exports = router;

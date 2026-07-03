const express = require('express');
const router = express.Router();
const { requireRole } = require('../auth');
const { serviceClient } = require('../supabase');
const { stringify } = require('csv-stringify');

// POST /api/exports/members — Higher Authority or Admin. Streams CSV of filtered member records.
router.post('/members', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin', 'higher_authority']);
  if (!ctx) return;

  const { region_id, district_id, constituency_id, membership_type, status, search } = req.body;

  let query = serviceClient()
    .from('members')
    .select(`
      member_number, first_name, last_name, date_of_birth, gender, phone, email,
      regions(name), districts(name), constituencies(name), polling_stations(name),
      ward, branch, membership_type, preferred_role, profession, employment_status,
      highest_academic_qualification, status, created_at
    `)
    .order('created_at', { ascending: false });

  if (region_id) query = query.eq('region_id', region_id);
  if (district_id) query = query.eq('district_id', district_id);
  if (constituency_id) query = query.eq('constituency_id', constituency_id);
  if (membership_type) query = query.eq('membership_type', membership_type);
  if (status) query = query.eq('status', status);
  if (search) query = query.textSearch('first_name', search);

  const { data, error } = await query;
  if (error) return res.status(500).json({ error: error.message });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename="members_export.csv"');

  const columns = [
    'member_number', 'first_name', 'last_name', 'date_of_birth', 'gender',
    'phone', 'email', 'region', 'district', 'constituency', 'polling_station',
    'ward', 'branch', 'membership_type', 'preferred_role', 'profession',
    'employment_status', 'highest_academic_qualification', 'status', 'created_at',
  ];

  const stringifier = stringify({ header: true, columns });
  stringifier.pipe(res);

  for (const row of data) {
    stringifier.write({
      ...row,
      region: row.regions?.name ?? '',
      district: row.districts?.name ?? '',
      constituency: row.constituencies?.name ?? '',
      polling_station: row.polling_stations?.name ?? '',
    });
  }
  stringifier.end();
});

module.exports = router;

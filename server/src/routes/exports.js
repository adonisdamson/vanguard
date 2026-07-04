const express = require('express');
const router = express.Router();
const { requireRole } = require('../auth');
const { serviceClient } = require('../supabase');
const { stringify } = require('csv-stringify');
const PDFDocument = require('pdfkit');

const PAGE_SIZE = 500; // rows per Supabase page — safe for 100k+ member sets

const COLUMNS = [
  { key: 'member_number',                  header: 'Member No.' },
  { key: 'first_name',                     header: 'First Name' },
  { key: 'last_name',                      header: 'Last Name' },
  { key: 'date_of_birth',                  header: 'DOB' },
  { key: 'gender',                         header: 'Gender' },
  { key: 'phone',                          header: 'Phone' },
  { key: 'email',                          header: 'Email' },
  { key: 'region',                         header: 'Region' },
  { key: 'district',                       header: 'District' },
  { key: 'constituency',                   header: 'Constituency' },
  { key: 'polling_station',                header: 'Polling Station' },
  { key: 'ward',                           header: 'Ward' },
  { key: 'branch',                         header: 'Branch' },
  { key: 'membership_type',               header: 'Membership Type' },
  { key: 'preferred_role',                header: 'Preferred Role' },
  { key: 'profession',                     header: 'Profession' },
  { key: 'employment_status',             header: 'Employment Status' },
  { key: 'highest_academic_qualification', header: 'Education' },
  { key: 'status',                         header: 'Status' },
  { key: 'created_at',                     header: 'Registered At' },
];

const SELECT_CLAUSE = `
  member_number, first_name, last_name, date_of_birth, gender, phone, email,
  regions(name), districts(name), constituencies(name), polling_stations(name),
  ward, branch, membership_type, preferred_role, profession, employment_status,
  highest_academic_qualification, status, created_at
`;

function applyFilters(query, { region_id, district_id, constituency_id, membership_type, status, search }) {
  if (region_id)       query = query.eq('region_id', region_id);
  if (district_id)     query = query.eq('district_id', district_id);
  if (constituency_id) query = query.eq('constituency_id', constituency_id);
  if (membership_type) query = query.eq('membership_type', membership_type);
  if (status)          query = query.eq('status', status);
  if (search)          query = query.or(`first_name.ilike.%${search}%,last_name.ilike.%${search}%`);
  return query;
}

function flattenRow(row) {
  return {
    ...row,
    region:          row.regions?.name          ?? '',
    district:        row.districts?.name        ?? '',
    constituency:    row.constituencies?.name   ?? '',
    polling_station: row.polling_stations?.name ?? '',
  };
}

// Async generator: yields one page at a time, never loads full dataset into memory.
async function* paginate(filters) {
  let from = 0;
  while (true) {
    const { data, error } = await applyFilters(
      serviceClient()
        .from('members')
        .select(SELECT_CLAUSE)
        .order('created_at', { ascending: false }),
      filters
    ).range(from, from + PAGE_SIZE - 1);

    if (error) throw new Error(error.message);
    for (const row of data) yield flattenRow(row);
    if (data.length < PAGE_SIZE) break;
    from += PAGE_SIZE;
  }
}

// ── POST /api/exports/members ─────────────────────────────────────────────────
// Body: { format?: 'csv'|'pdf', region_id?, district_id?, constituency_id?,
//         membership_type?, status?, search? }
// Higher Authority or Admin only.
router.post('/members', async (req, res) => {
  const ctx = await requireRole(req, res, ['admin', 'higher_authority']);
  if (!ctx) return;

  const { format = 'csv', ...filters } = req.body;

  try {
    if (format === 'pdf') {
      await streamPdf(res, filters);
    } else {
      await streamCsv(res, filters);
    }
  } catch (err) {
    // Only send error header if headers haven't been flushed yet
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    } else {
      res.destroy();
    }
  }
});

// ── CSV ───────────────────────────────────────────────────────────────────────
async function streamCsv(res, filters) {
  const ts = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="members_${ts}.csv"`);

  const stringifier = stringify({
    header: true,
    columns: COLUMNS.map(c => ({ key: c.key, header: c.header })),
  });
  stringifier.pipe(res);

  for await (const row of paginate(filters)) {
    if (!stringifier.write(row)) {
      // Back-pressure: wait for drain before continuing
      await new Promise(resolve => stringifier.once('drain', resolve));
    }
  }
  stringifier.end();
}

// ── PDF ───────────────────────────────────────────────────────────────────────
const NDC_GREEN  = '#006B3F';
const NDC_RED    = '#CE1126';
const NDC_BLACK  = '#1A1A1A';
const MIST       = '#647169';

// Columns to include in the PDF table (subset — full 20-col set is too wide for A4)
const PDF_COLS = [
  { key: 'member_number',   header: 'Member No.',   width: 90 },
  { key: 'first_name',      header: 'First Name',   width: 80 },
  { key: 'last_name',       header: 'Last Name',    width: 80 },
  { key: 'gender',          header: 'Gender',       width: 45 },
  { key: 'phone',           header: 'Phone',        width: 90 },
  { key: 'constituency',    header: 'Constituency', width: 90 },
  { key: 'polling_station', header: 'Polling Stn',  width: 90 },
  { key: 'status',          header: 'Status',       width: 60 },
];

const ROW_H    = 18;
const HEADER_H = 24;
const MARGIN   = 36;
const PAGE_W   = 595.28; // A4 portrait pt
const PAGE_H   = 841.89;
const TABLE_W  = PDF_COLS.reduce((s, c) => s + c.width, 0);
const TABLE_X  = MARGIN;

async function streamPdf(res, filters) {
  const ts = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="members_${ts}.pdf"`);

  const doc = new PDFDocument({ size: 'A4', margin: MARGIN, autoFirstPage: true });
  doc.pipe(res);

  let y = MARGIN;
  let pageNum = 1;
  let rowCount = 0;
  let isFirstPage = true;

  function drawPageHeader() {
    // Green bar
    doc.rect(0, 0, PAGE_W, 48).fill(NDC_GREEN);
    // Title
    doc.fillColor('#FFFFFF').fontSize(16).font('Helvetica-Bold')
       .text('NDC Vanguard — Member Register', MARGIN, 14, { width: PAGE_W - MARGIN * 2 });
    doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica')
       .text(`Generated ${new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}   ·   Page ${pageNum}`,
             MARGIN, 32, { width: PAGE_W - MARGIN * 2 });
    // Red accent stripe
    doc.rect(0, 48, PAGE_W, 3).fill(NDC_RED);
    return 60; // next y
  }

  function drawTableHeader(y) {
    doc.rect(TABLE_X, y, TABLE_W, HEADER_H).fill(NDC_GREEN);
    let x = TABLE_X;
    for (const col of PDF_COLS) {
      doc.fillColor('#FFFFFF').fontSize(7).font('Helvetica-Bold')
         .text(col.header, x + 3, y + 7, { width: col.width - 6, ellipsis: true });
      x += col.width;
    }
    return y + HEADER_H;
  }

  function drawRow(row, y, even) {
    // Alternating row fill
    if (even) doc.rect(TABLE_X, y, TABLE_W, ROW_H).fill('#F2F6F4');
    let x = TABLE_X;
    for (const col of PDF_COLS) {
      const val = String(row[col.key] ?? '');
      doc.fillColor(NDC_BLACK).fontSize(6.5).font('Helvetica')
         .text(val, x + 3, y + 5, { width: col.width - 6, ellipsis: true });
      x += col.width;
    }
    // Bottom border
    doc.moveTo(TABLE_X, y + ROW_H).lineTo(TABLE_X + TABLE_W, y + ROW_H)
       .strokeColor('#E0E8E4').lineWidth(0.5).stroke();
  }

  function drawColumnBorders(tableTopY, tableBottomY) {
    let x = TABLE_X;
    doc.strokeColor('#C8D8D0').lineWidth(0.5);
    for (const col of PDF_COLS) {
      doc.moveTo(x, tableTopY).lineTo(x, tableBottomY).stroke();
      x += col.width;
    }
    doc.moveTo(x, tableTopY).lineTo(x, tableBottomY).stroke();
  }

  function newPage() {
    doc.addPage();
    pageNum++;
    return drawPageHeader();
  }

  // First page header
  y = drawPageHeader();
  isFirstPage = false;
  let tableTopY = y;
  y = drawTableHeader(y);

  for await (const row of paginate(filters)) {
    // Check if we need a new page (leave room for footer)
    if (y + ROW_H > PAGE_H - MARGIN - 20) {
      drawColumnBorders(tableTopY, y);
      // Page footer
      doc.fillColor(MIST).fontSize(7).font('Helvetica')
         .text(`NDC Tema West Constituency Register — Confidential`, MARGIN, PAGE_H - 20,
               { width: PAGE_W - MARGIN * 2, align: 'center' });
      y = newPage();
      tableTopY = y;
      y = drawTableHeader(y);
    }

    drawRow(row, y, rowCount % 2 === 0);
    y += ROW_H;
    rowCount++;
  }

  // Close last table
  drawColumnBorders(tableTopY, y);

  // Summary row
  y += 8;
  doc.fillColor(MIST).fontSize(8).font('Helvetica')
     .text(`Total records: ${rowCount}`, TABLE_X, y);

  // Footer on last page
  doc.fillColor(MIST).fontSize(7)
     .text('NDC Tema West Constituency Register — Confidential', MARGIN, PAGE_H - 20,
           { width: PAGE_W - MARGIN * 2, align: 'center' });

  doc.end();
}

module.exports = router;

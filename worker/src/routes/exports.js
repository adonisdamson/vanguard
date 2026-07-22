import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import { requireRole } from '../auth.js';
import { serviceClient } from '../supabase.js';

const exports_ = new Hono();

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
  { key: 'membership_type',                header: 'Membership Type' },
  { key: 'preferred_role',                 header: 'Preferred Role' },
  { key: 'profession',                     header: 'Profession' },
  { key: 'employment_status',              header: 'Employment Status' },
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

// Resolve the caller's data jurisdiction. Admins are national (no scope).
// A higher_authority/personnel with an assignment is pinned to it; a null
// assignment means national. Read from the DB, never the client — the export
// runs under the service key (RLS off), so scope MUST be enforced here.
async function jurisdictionFor(env, ctx) {
  if (ctx.role === 'admin') return {};
  const { data, error } = await serviceClient(env)
    .from('app_users')
    .select('assigned_region_id, assigned_constituency_id')
    .eq('id', ctx.user.id)
    .single();
  if (error || !data) {
    // Fail closed: if we can't resolve the scope, don't hand over data.
    throw new Error('Could not resolve caller jurisdiction');
  }
  const scope = {};
  if (data.assigned_region_id)       scope.region_id = data.assigned_region_id;
  if (data.assigned_constituency_id) scope.constituency_id = data.assigned_constituency_id;
  return scope;
}

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

// Async generator: yields one page at a time, never loads the full dataset.
async function* paginate(env, filters) {
  let from = 0;
  while (true) {
    const { data, error } = await applyFilters(
      serviceClient(env)
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
exports_.post('/members', async (c) => {
  const ctx = await requireRole(c, ['admin', 'higher_authority', 'manager']);
  const { format = 'csv', ...filters } = await c.req.json().catch(() => ({}));

  // Pin the caller's jurisdiction LAST so it overrides any region/constituency
  // the client tried to widen to. Client filters (district/status/search) may
  // still narrow further within scope.
  const scope = await jurisdictionFor(c.env, ctx);
  const effective = { ...filters, ...scope };

  return format === 'pdf'
    ? streamPdf(c, effective)
    : streamCsv(c, effective);
});

// ── CSV ───────────────────────────────────────────────────────────────────────
// RFC 4180 escaping. Wrapped in quotes if the value contains comma, quote,
// CR or LF; embedded quotes are doubled.
function csvCell(value) {
  const s = value == null ? '' : String(value);
  if (/[",\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function csvLine(values) {
  return values.map(csvCell).join(',') + '\r\n';
}

function streamCsv(c, filters) {
  const ts = new Date().toISOString().slice(0, 10);
  const env = c.env;

  const body = new ReadableStream({
    async start(controller) {
      const enc = new TextEncoder();
      try {
        controller.enqueue(enc.encode(csvLine(COLUMNS.map((col) => col.header))));
        for await (const row of paginate(env, filters)) {
          controller.enqueue(enc.encode(csvLine(COLUMNS.map((col) => row[col.key]))));
        }
        controller.close();
      } catch (err) {
        // Headers are already sent by the time we stream — abort the body so the
        // client sees a truncated/failed download rather than a silent partial.
        controller.error(err);
      }
    },
  });

  return new Response(body, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="members_${ts}.csv"`,
      'Cache-Control': 'no-store',
    },
  });
}

// ── PDF (pdf-lib) ─────────────────────────────────────────────────────────────
// pdf-lib uses a bottom-left origin; the layout below is authored top-left (as
// the original pdfkit code was) and converted at draw time via ty()/rectY().
const NDC_GREEN = rgb(0, 0x6b / 255, 0x3f / 255);
const NDC_RED   = rgb(0xce / 255, 0x11 / 255, 0x26 / 255);
const NDC_BLACK = rgb(0x1a / 255, 0x1a / 255, 0x1a / 255);
const MIST      = rgb(0x64 / 255, 0x71 / 255, 0x69 / 255);
const WHITE     = rgb(1, 1, 1);
const ROW_FILL  = rgb(0xf2 / 255, 0xf6 / 255, 0xf4 / 255);
const ROW_LINE  = rgb(0xe0 / 255, 0xe8 / 255, 0xe4 / 255);
const COL_LINE  = rgb(0xc8 / 255, 0xd8 / 255, 0xd0 / 255);

// Subset of columns — the full 20-col set is too wide for A4 portrait.
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
const TABLE_W  = PDF_COLS.reduce((s, col) => s + col.width, 0);
const TABLE_X  = MARGIN;

async function streamPdf(c, filters) {
  const ts = new Date().toISOString().slice(0, 10);

  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);

  let page = doc.addPage([PAGE_W, PAGE_H]);
  let pageNum = 1;

  // Coordinate helpers: convert a top-left y to pdf-lib's bottom-left space.
  const rectY = (topY, h) => PAGE_H - topY - h;            // rectangle bottom edge
  const textY = (topY, size) => PAGE_H - topY - size;      // baseline for text box

  // Truncate text to fit a column width (pdf-lib has no built-in ellipsis).
  function fit(text, f, size, maxWidth) {
    let s = String(text ?? '');
    if (f.widthOfTextAtSize(s, size) <= maxWidth) return s;
    while (s.length > 1 && f.widthOfTextAtSize(s + '…', size) > maxWidth) {
      s = s.slice(0, -1);
    }
    return s + '…';
  }

  function drawText(p, text, x, topY, size, f, color, maxWidth) {
    p.drawText(fit(text, f, size, maxWidth), {
      x, y: textY(topY, size), size, font: f, color,
    });
  }

  function drawPageHeader(p) {
    p.drawRectangle({ x: 0, y: rectY(0, 48), width: PAGE_W, height: 48, color: NDC_GREEN });
    drawText(p, 'NDC Vanguard — Member Register', MARGIN, 14, 16, bold, WHITE, PAGE_W - MARGIN * 2);
    const gen = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
    drawText(p, `Generated ${gen}   ·   Page ${pageNum}`, MARGIN, 34, 9, font, WHITE, PAGE_W - MARGIN * 2);
    p.drawRectangle({ x: 0, y: rectY(48, 3), width: PAGE_W, height: 3, color: NDC_RED });
    return 60; // next y
  }

  function drawTableHeader(p, y) {
    p.drawRectangle({ x: TABLE_X, y: rectY(y, HEADER_H), width: TABLE_W, height: HEADER_H, color: NDC_GREEN });
    let x = TABLE_X;
    for (const col of PDF_COLS) {
      drawText(p, col.header, x + 3, y + 7, 7, bold, WHITE, col.width - 6);
      x += col.width;
    }
    return y + HEADER_H;
  }

  function drawRow(p, row, y, even) {
    if (even) p.drawRectangle({ x: TABLE_X, y: rectY(y, ROW_H), width: TABLE_W, height: ROW_H, color: ROW_FILL });
    let x = TABLE_X;
    for (const col of PDF_COLS) {
      drawText(p, row[col.key], x + 3, y + 5, 6.5, font, NDC_BLACK, col.width - 6);
      x += col.width;
    }
    const lineY = PAGE_H - (y + ROW_H);
    p.drawLine({ start: { x: TABLE_X, y: lineY }, end: { x: TABLE_X + TABLE_W, y: lineY }, thickness: 0.5, color: ROW_LINE });
  }

  function drawColumnBorders(p, topY, bottomY) {
    let x = TABLE_X;
    for (let i = 0; i <= PDF_COLS.length; i++) {
      p.drawLine({
        start: { x, y: PAGE_H - topY },
        end: { x, y: PAGE_H - bottomY },
        thickness: 0.5, color: COL_LINE,
      });
      if (i < PDF_COLS.length) x += PDF_COLS[i].width;
    }
  }

  function drawFooter(p) {
    drawText(p, 'NDC Tema West Constituency Register — Confidential',
      MARGIN, PAGE_H - 20, 7, font, MIST, PAGE_W - MARGIN * 2);
  }

  let y = drawPageHeader(page);
  let tableTopY = y;
  y = drawTableHeader(page, y);

  let rowCount = 0;
  for await (const row of paginate(c.env, filters)) {
    if (y + ROW_H > PAGE_H - MARGIN - 20) {
      drawColumnBorders(page, tableTopY, y);
      drawFooter(page);
      page = doc.addPage([PAGE_W, PAGE_H]);
      pageNum++;
      y = drawPageHeader(page);
      tableTopY = y;
      y = drawTableHeader(page, y);
    }
    drawRow(page, row, y, rowCount % 2 === 0);
    y += ROW_H;
    rowCount++;
  }

  drawColumnBorders(page, tableTopY, y);
  drawText(page, `Total records: ${rowCount}`, TABLE_X, y + 8, 8, font, MIST, TABLE_W);
  drawFooter(page);

  const bytes = await doc.save();
  return new Response(bytes, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="members_${ts}.pdf"`,
      'Cache-Control': 'no-store',
    },
  });
}

export default exports_;

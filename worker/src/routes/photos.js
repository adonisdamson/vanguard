import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requireAuth } from '../auth.js';

const photos = new Hono();

const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB — generous for a phone photo

// Keys are `{auth.uid}/...`. A user may only write under their own prefix; the
// prefix is derived from the verified JWT, never trusted from the client.
function ownsKey(key, uid) {
  if (!key || key.includes('..') || key.includes('//') || key.startsWith('/')) return false;
  return key.startsWith(`${uid}/`);
}

// POST /api/photos/upload?key={uid}/...  — raw image bytes in the body.
// Replaces the old direct-to-Supabase-Storage upload. Bytes are stored in the
// private R2 bucket via the binding; the client keeps the returned key in
// members.photo_path / app_users.avatar_path (same key format as before).
photos.post('/upload', async (c) => {
  const user = await requireAuth(c);

  const key = c.req.query('key');
  if (!ownsKey(key, user.id)) {
    throw new HTTPException(400, { message: 'Invalid or unauthorized photo key' });
  }

  const contentType = (c.req.header('content-type') || '').split(';')[0].trim();
  if (!ALLOWED_TYPES.has(contentType)) {
    throw new HTTPException(415, { message: 'Only JPEG, PNG or WebP images are allowed' });
  }

  const body = await c.req.arrayBuffer();
  if (!body || body.byteLength === 0) {
    throw new HTTPException(400, { message: 'Empty image body' });
  }
  if (body.byteLength > MAX_BYTES) {
    throw new HTTPException(413, { message: 'Image exceeds 10 MB limit' });
  }

  await c.env.MEMBER_PHOTOS.put(key, body, { httpMetadata: { contentType } });
  return c.json({ key });
});

// GET /api/photos/view?key=...  — any authenticated operator (reviewers view
// all member photos, matching the old bucket's authenticated-read policy).
// Streams the bytes from R2. PII stays private: never a public URL.
photos.get('/view', async (c) => {
  await requireAuth(c);

  const key = c.req.query('key');
  if (!key || key.includes('..')) {
    throw new HTTPException(400, { message: 'Invalid key' });
  }

  const obj = await c.env.MEMBER_PHOTOS.get(key);
  if (!obj) throw new HTTPException(404, { message: 'Photo not found' });

  const headers = new Headers();
  obj.writeHttpMetadata(headers); // sets Content-Type from stored metadata
  headers.set('etag', obj.httpEtag);
  // Private (auth required) but cache for 1 hour; revalidate up to 5 min
  // stale while fresh copy is fetched — keeps the UI snappy on repeat visits.
  headers.set('Cache-Control', 'private, max-age=3600, stale-while-revalidate=300');

  const origin = c.req.header('Origin');
  if (origin) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Access-Control-Allow-Credentials', 'true');
    headers.set('Vary', 'Origin');
  }

  return new Response(obj.body, { headers });
});

export default photos;

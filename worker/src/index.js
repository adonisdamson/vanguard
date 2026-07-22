import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { bodyLimit } from 'hono/body-limit';
import { HTTPException } from 'hono/http-exception';

import members from './routes/members.js';
import admin from './routes/admin.js';
import exports_ from './routes/exports.js';
import download from './routes/download.js';
import photos from './routes/photos.js';

const app = new Hono();

// ── CORS ──────────────────────────────────────────────────────────────────────
// The API is consumed by the native app (no Origin header — always allowed) and
// by the download landing page. Browsers get no cross-origin access unless the
// origin is listed in ALLOWED_ORIGINS (comma-separated env var).
app.use('*', cors({
  origin: (origin, c) => {
    if (!origin) return origin; // native app / curl — no Origin header
    const allowed = (c.env.ALLOWED_ORIGINS || '')
      .split(',').map((s) => s.trim()).filter(Boolean);
    return allowed.includes(origin) ? origin : null;
  },
}));

// ── Rate limiting ─────────────────────────────────────────────────────────────
// Cloudflare native rate-limit bindings (see wrangler.toml). Keyed by edge IP.
// Skipped gracefully if the binding isn't present (e.g. an unconfigured env).
function rateLimit(bindingName, message) {
  return async (c, next) => {
    const limiter = c.env[bindingName];
    if (limiter) {
      const key = c.req.header('cf-connecting-ip') || 'anonymous';
      const { success } = await limiter.limit({ key });
      if (!success) return c.json({ error: message }, 429);
    }
    await next();
  };
}

// Blunt global limit across the whole public surface.
app.use('*', rateLimit('RATE_LIMITER', 'Too many requests — slow down and try again shortly.'));
// JSON body cap for the JSON API surface (matches the old 256kb express limit).
// Photo upload is exempt (raw image bytes) and capped separately below.
app.use('/api/members/*', bodyLimit({ maxSize: 256 * 1024 }));
app.use('/api/admin/*', bodyLimit({ maxSize: 256 * 1024 }));
app.use('/api/exports/*', bodyLimit({ maxSize: 256 * 1024 }));
app.use('/api/photos/upload', bodyLimit({ maxSize: 10 * 1024 * 1024 }));
// Tighter limit on the privileged admin surface (account creation, resets).
app.use('/api/admin/operators/*', rateLimit('ADMIN_RATE_LIMITER', 'Too many admin actions — slow down and try again shortly.'));
app.use('/api/admin/operators', rateLimit('ADMIN_RATE_LIMITER', 'Too many admin actions — slow down and try again shortly.'));

// ── Routes ────────────────────────────────────────────────────────────────────
app.route('/api/members', members);
app.route('/api/admin/operators', admin);
app.route('/api/exports', exports_);
app.route('/api/photos', photos);
app.route('/download', download);

app.get('/health', (c) => c.json({ ok: true }));

// ── Error formatting ──────────────────────────────────────────────────────────
app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ error: err.message }, err.status);
  }
  console.error('[unhandled]', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;

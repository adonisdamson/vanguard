require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const membersRouter = require('./routes/members');
const adminRouter = require('./routes/admin');
const exportsRouter = require('./routes/exports');
const downloadRouter = require('./routes/download');

const app = express();

// Behind Railway's proxy — required for correct client IPs (rate limiting,
// and the capture-metadata x-forwarded-for read).
app.set('trust proxy', 1);

// Security headers (CSP off — this is a JSON API + APK stream, not a web app).
app.use(helmet({ contentSecurityPolicy: false }));

// CORS: the API is only consumed by the native app and the download links.
// The native app sends no Origin header; browsers get no cross-origin access
// unless the origin is explicitly listed in ALLOWED_ORIGINS (comma-separated).
const allowed = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // native app / curl — no Origin header
      return cb(null, allowed.includes(origin));
    },
  })
);

app.use(express.json({ limit: '256kb' }));

// Global rate limit — blunt brute-force / abuse of the public API surface.
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 120,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests — slow down and try again shortly.' },
  })
);

// Tighter limit on the privileged admin surface (account creation, password
// resets, approvals) — these should never be hit in bursts.
const adminLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many admin actions — slow down and try again shortly.' },
});

app.use('/api/members', membersRouter);
app.use('/api/admin/operators', adminLimiter, adminRouter);
app.use('/api/exports', exportsRouter);

app.use('/download', downloadRouter);
app.get('/health', (_, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Vanguard API listening on :${PORT}`));

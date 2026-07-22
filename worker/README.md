# Vanguard API — Cloudflare Workers

Replaces the former Railway/Express backend (`../server`). This Worker is the
**only** place the Supabase `service_role` key is ever loaded.

Runtime: [Hono](https://hono.dev) on Cloudflare Workers. PDF export uses
`pdf-lib` (Workers-safe); CSV export streams via Web Streams; push uses the FCM
HTTP v1 API with Web Crypto JWT signing (no `firebase-admin`).

## Endpoints (unchanged contract)

| Route | Method | Auth |
|---|---|---|
| `/health` | GET | none |
| `/api/members/:id/capture-metadata` | POST | owner operator |
| `/api/admin/operators` (+ `/:id/suspend`, `/reactivate`, `/role`, `/password`, `/approve`, `/decline`) | POST | admin |
| `/api/exports/members` | POST | admin / higher_authority |
| `/download` and `/download/version` | GET | none |

Client IP is read from `CF-Connecting-IP` (more reliable than `x-forwarded-for`).

## Local dev

```bash
npm install
cp .dev.vars.example .dev.vars   # fill in SUPABASE_SERVICE_ROLE_KEY etc.
# set SUPABASE_URL / SUPABASE_ANON_KEY in wrangler.toml [vars] to real values
npm run dev
curl localhost:8787/health        # {"ok":true}
```

## Deploy

```bash
# 1. Set the real public values in wrangler.toml [vars]:
#    SUPABASE_URL, SUPABASE_ANON_KEY, ALLOWED_ORIGINS

# 2. Set secrets (never committed):
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put GITHUB_TOKEN            # optional
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT # optional (JSON string), enables push

# 3. Deploy
npm run deploy
```

Then point the Flutter app at the deployed URL by setting `API_BASE_URL` in the
app's `.env` (falls back to the legacy `RAILWAY_API_URL` if unset).

## Notes / trade-offs vs the old Express server

- **PDF** is built fully in memory (pdf-lib can't stream incrementally). Fine for
  filtered/moderate sets; for a full 100k-row dump prefer **CSV**, which streams.
- **Download cache** is per-isolate best-effort (same semantics as the old
  module-level cache) — a cold isolate simply re-fetches from GitHub.
- Rate limiting uses Cloudflare's native rate-limit bindings (see `wrangler.toml`),
  replacing `express-rate-limit`.

import { Hono } from 'hono';

const download = new Hono();

const REPO = 'adonisdamson/vanguard';
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes — APK URL is stable between releases

// Best-effort in-memory slot, scoped to a single Worker isolate. Cheaper than
// hitting GitHub on every request; a cold isolate simply re-fetches. Same
// semantics as the old server's module-level cache.
let _cache = null;

async function fetchLatestAsset(env) {
  if (_cache && Date.now() < _cache.expiresAt) return _cache.asset;

  const headers = {
    'User-Agent': 'vanguard-download/1.0',
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  // Optional token: bumps GitHub rate limit from 60 → 5000 req/hr.
  if (env.GITHUB_TOKEN) headers['Authorization'] = `Bearer ${env.GITHUB_TOKEN}`;

  const resp = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
    headers,
    signal: AbortSignal.timeout(15000),
  });
  if (!resp.ok) throw new Error(`GitHub API ${resp.status}`);

  const release = await resp.json();
  const asset = (release.assets || []).find((a) => a.name.endsWith('.apk')) || null;
  if (asset) _cache = { asset, expiresAt: Date.now() + CACHE_TTL_MS };
  return asset;
}

// Streams an already-fetched upstream APK response through the Worker so the
// client never sees GitHub. Sanitises the filename to prevent header injection.
function streamApk(upstream, name) {
  const safeName = name.replace(/[^\w.\-]/g, '_');
  const headers = new Headers({
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Disposition': `attachment; filename="${safeName}"`,
    'Cache-Control': 'no-store, no-cache, must-revalidate',
    Pragma: 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  });
  const len = upstream.headers.get('content-length');
  if (len) headers.set('Content-Length', len);
  return new Response(upstream.body, { headers });
}

// The release tag is fixed (`latest`) and the prod build attaches a stable-named
// asset, so this URL is deterministic across versions — no GitHub API call, and
// therefore none of the unauthenticated-rate-limit 503 flakiness.
const STABLE_APK_URL = `https://github.com/${REPO}/releases/download/latest/TemaWest-NDC.apk`;

// GET /download — streams the latest production APK.
download.get('/', async (c) => {
  // Primary path: deterministic stable asset, streamed server-side. No API call.
  try {
    const upstream = await fetch(STABLE_APK_URL, {
      headers: { 'User-Agent': 'vanguard-download/1.0' },
      redirect: 'follow',
      signal: AbortSignal.timeout(60000),
    });
    if (upstream.ok && upstream.body) return streamApk(upstream, 'TemaWest-NDC.apk');
  } catch {
    // fall through to API resolution below
  }

  // Fallback: resolve the versioned asset via the API (e.g. an older release
  // published before the stable-named asset existed).
  let asset;
  try {
    asset = await fetchLatestAsset(c.env);
  } catch {
    asset = null;
  }
  if (!asset) return c.text('APK unavailable — try again shortly', 503);

  const upstream = await fetch(asset.browser_download_url, {
    headers: { 'User-Agent': 'vanguard-download/1.0' },
    signal: AbortSignal.timeout(60000),
  });
  if (!upstream.ok || !upstream.body) return c.text('APK unavailable', 502);
  return streamApk(upstream, asset.name);
});

// GET /download/version — live release metadata for the landing page.
download.get('/version', async (c) => {
  let asset;
  try {
    asset = await fetchLatestAsset(c.env);
  } catch {
    asset = null;
  }
  if (!asset) return c.json({ error: 'Version info unavailable' }, 503);

  const match = asset.name.match(/v(\d+(?:\.\d+)*)/);
  c.header('Cache-Control', 'public, max-age=300'); // 5-min CDN cache is fine here
  return c.json({
    version: match ? match[1] : null,
    filename: asset.name,
    size_bytes: asset.size,
    download_count: asset.download_count,
    updated_at: asset.updated_at,
    // Direct GitHub CDN URL — lets the in-app updater pull the APK without
    // streaming it through the Worker. `/download` remains the proxy fallback.
    download_url: asset.browser_download_url,
  });
});

export default download;

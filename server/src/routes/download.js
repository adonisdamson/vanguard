const express = require('express');
const https = require('https');
const http = require('http');

const router = express.Router();

const REPO = 'adonisdamson/vanguard';
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes — APK URL is stable between releases

// Single in-memory slot: invalidated automatically after TTL or on every new
// release (which replaces the `latest` tag, so the next real request wins).
let _cache = null;

function fetchLatestAsset(cb) {
  if (_cache && Date.now() < _cache.expiresAt) {
    return cb(null, _cache.asset);
  }

  const headers = {
    'User-Agent': 'vanguard-download/1.0',
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  // Optional token from Railway env: bumps rate limit from 60 → 5000 req/hr.
  if (process.env.GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  const req = https.get(
    `https://api.github.com/repos/${REPO}/releases/latest`,
    { headers },
    (resp) => {
      let body = '';
      resp.on('data', (c) => (body += c));
      resp.on('end', () => {
        try {
          const release = JSON.parse(body);
          const asset = (release.assets || []).find((a) => a.name.endsWith('.apk'));
          if (asset) {
            _cache = { asset, expiresAt: Date.now() + CACHE_TTL_MS };
          }
          cb(null, asset || null);
        } catch (e) {
          cb(e);
        }
      });
    }
  );
  req.on('error', cb);
  req.setTimeout(15000, () => {
    req.destroy();
    cb(new Error('GitHub API timeout'));
  });
}

function streamFollowingRedirects(url, res, depth = 0) {
  if (depth > 8) {
    res.status(503).send('Too many redirects');
    return;
  }
  const urlObj = new URL(url);
  const client = urlObj.protocol === 'https:' ? https : http;
  const req = client.get(
    url,
    { headers: { 'User-Agent': 'vanguard-download/1.0' } },
    (upstream) => {
      if (upstream.statusCode >= 300 && upstream.statusCode < 400 && upstream.headers.location) {
        upstream.resume();
        streamFollowingRedirects(upstream.headers.location, res, depth + 1);
        return;
      }
      if (upstream.statusCode === 200) {
        if (upstream.headers['content-length']) {
          res.setHeader('Content-Length', upstream.headers['content-length']);
        }
        upstream.pipe(res);
        return;
      }
      res.status(502).send('APK unavailable');
    }
  );
  req.on('error', () => {
    if (!res.headersSent) res.status(503).send('Download failed');
  });
  req.setTimeout(60000, () => {
    req.destroy();
    if (!res.headersSent) res.status(504).send('Upstream timeout');
  });
}

// GET /download — streams the latest production APK
router.get('/', (req, res) => {
  fetchLatestAsset((err, asset) => {
    if (err || !asset) {
      res.status(503).send('APK unavailable — try again shortly');
      return;
    }
    // Sanitise the filename before placing it in a header to prevent injection.
    const safeName = asset.name.replace(/[^\w.\-]/g, '_');
    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName}"`);
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    streamFollowingRedirects(asset.browser_download_url, res);
  });
});

// GET /download/version — returns current release metadata as JSON.
// Used by the landing page to show the live version number.
router.get('/version', (req, res) => {
  fetchLatestAsset((err, asset) => {
    if (err || !asset) {
      return res.status(503).json({ error: 'Version info unavailable' });
    }
    const match = asset.name.match(/v([\d.]+)/);
    res.setHeader('Cache-Control', 'public, max-age=300'); // 5-min CDN cache is fine for version info
    res.json({
      version: match ? match[1] : null,
      filename: asset.name,
      size_bytes: asset.size,
      download_count: asset.download_count,
      updated_at: asset.updated_at,
    });
  });
});

module.exports = router;

const express = require('express');
const https = require('https');
const http = require('http');

const router = express.Router();

const REPO = 'adonisdamson/vanguard';

function streamFollowingRedirects(url, res, depth = 0) {
  if (depth > 8) {
    res.status(503).send('Too many redirects');
    return;
  }
  const urlObj = new URL(url);
  const client = urlObj.protocol === 'https:' ? https : http;
  const req = client.get(
    url,
    { headers: { 'User-Agent': 'vanguard-api-download/1.0' } },
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
  req.setTimeout(30000, () => {
    req.destroy();
    if (!res.headersSent) res.status(504).send('Upstream timeout');
  });
}

// Resolve the newest release's single versioned APK via the GitHub API —
// each build recreates the release, so the asset name changes every version
// and can never be served stale from any cache.
function fetchLatestAsset(cb) {
  const req = https.get(
    `https://api.github.com/repos/${REPO}/releases/latest`,
    {
      headers: {
        'User-Agent': 'vanguard-api-download/1.0',
        Accept: 'application/vnd.github+json',
      },
    },
    (resp) => {
      let body = '';
      resp.on('data', (c) => (body += c));
      resp.on('end', () => {
        try {
          const release = JSON.parse(body);
          const asset = (release.assets || []).find((a) => a.name.endsWith('.apk'));
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

// GET /download — streams the latest APK with no GitHub exposure
router.get('/', (req, res) => {
  fetchLatestAsset((err, asset) => {
    if (err || !asset) {
      res.status(503).send('APK unavailable — try again shortly');
      return;
    }
    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader('Content-Disposition', `attachment; filename="${asset.name}"`);
    // NEVER cache: phones re-served stale APKs for days when this endpoint
    // carried a public max-age with a constant filename.
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    streamFollowingRedirects(asset.browser_download_url, res);
  });
});

module.exports = router;

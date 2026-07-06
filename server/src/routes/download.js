const express = require('express');
const https = require('https');
const http = require('http');

const router = express.Router();

const REPO = 'adonisdamson/vanguard';
const ASSET = 'vanguard-latest.apk';
const FALLBACK_URL = `https://github.com/${REPO}/releases/latest/download/${ASSET}`;

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

// GET /download — streams the latest APK with no GitHub exposure
router.get('/', (req, res) => {
  res.setHeader('Content-Type', 'application/vnd.android.package-archive');
  res.setHeader('Content-Disposition', 'attachment; filename="Vanguard-NDC.apk"');
  // NEVER cache: with a constant filename + max-age, phones re-served a stale
  // APK for every "new" download — users kept reinstalling an old build while
  // believing they had the latest release.
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  streamFollowingRedirects(FALLBACK_URL, res);
});

module.exports = router;

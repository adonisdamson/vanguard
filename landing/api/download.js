// Vercel Edge Function — streams the latest APK straight from the GitHub
// release. Self-contained: no dependency on the Railway backend, and no way
// to serve a stale build because (a) the release lookup is always fetched
// no-store, (b) each release exposes exactly ONE apk asset with a version-
// stamped filename, and (c) the response itself is no-store.
export const config = { runtime: 'edge' };

const REPO = 'adonisdamson/vanguard';

export default async function handler() {
  try {
    // 1. Latest release — fetched no-store so we never see a cached release.
    const apiRes = await fetch(
      `https://api.github.com/repos/${REPO}/releases/latest`,
      {
        cache: 'no-store',
        headers: {
          Accept: 'application/vnd.github+json',
          'User-Agent': 'vanguard-web',
          'X-GitHub-Api-Version': '2022-11-28',
          ...(process.env.GITHUB_TOKEN
            ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }
            : {}),
        },
      }
    );
    if (!apiRes.ok) {
      return new Response(`GitHub API error: ${apiRes.status}`, {
        status: 502,
        headers: { 'Cache-Control': 'no-store' },
      });
    }

    const release = await apiRes.json();
    // One versioned APK per release — grab it by extension.
    const asset = (release.assets || []).find((a) => a.name.endsWith('.apk'));
    if (!asset) {
      return new Response('APK not available yet — check back shortly.', {
        status: 503,
        headers: { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' },
      });
    }

    // 2. Fetch the actual bytes from the GitHub CDN (also no-store).
    const apkRes = await fetch(asset.browser_download_url, { cache: 'no-store' });
    if (!apkRes.ok) {
      return new Response('APK fetch failed.', {
        status: 502,
        headers: { 'Cache-Control': 'no-store' },
      });
    }

    // 3. Stream to the user under the real versioned filename — never cached.
    return new Response(apkRes.body, {
      status: 200,
      headers: {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': `attachment; filename="${asset.name}"`,
        'Content-Length': String(asset.size),
        'Cache-Control': 'no-store, no-cache, must-revalidate',
        'Pragma': 'no-cache',
      },
    });
  } catch (err) {
    return new Response(`Error: ${err.message}`, {
      status: 500,
      headers: { 'Cache-Control': 'no-store' },
    });
  }
}

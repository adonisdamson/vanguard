// Vercel Edge Function — streams the APK directly from GitHub release.
// Users see only yoursite.vercel.app/download — no GitHub URL, ever.
export const config = { runtime: 'edge' };

const REPO = 'adonisdamson/vanguard';
const ASSET = 'vanguard-latest.apk';

export default async function handler(req) {
  try {
    // 1. Ask GitHub API for the latest release
    const apiRes = await fetch(
      `https://api.github.com/repos/${REPO}/releases/latest`,
      {
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
      return new Response(`GitHub API error: ${apiRes.status}`, { status: 502 });
    }

    const release = await apiRes.json();
    const asset = release.assets?.find(a => a.name === ASSET);

    if (!asset) {
      return new Response('APK not available yet — check back shortly.', {
        status: 503,
        headers: { 'Content-Type': 'text/plain' },
      });
    }

    // 2. Fetch the actual APK bytes from GitHub CDN
    const apkRes = await fetch(asset.browser_download_url);

    if (!apkRes.ok) {
      return new Response('APK fetch failed.', { status: 502 });
    }

    // 3. Stream it straight to the user — no redirect, no GitHub URL visible
    return new Response(apkRes.body, {
      status: 200,
      headers: {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': `attachment; filename="${ASSET}"`,
        'Content-Length': String(asset.size),
        'Cache-Control': 'no-store',
      },
    });
  } catch (err) {
    return new Response(`Error: ${err.message}`, { status: 500 });
  }
}

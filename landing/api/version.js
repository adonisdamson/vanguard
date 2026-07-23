// Vercel Edge Function — returns live metadata for the latest production APK.
// Self-contained (GitHub-direct, no Railway/Worker dependency) so the landing
// page's version badge always reflects the newest `latest` release, and the
// same JSON can drive an in-app update check.
export const config = { runtime: 'edge' };

const REPO = 'adonisdamson/vanguard';

export default async function handler() {
  try {
    const res = await fetch(
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
    if (!res.ok) {
      return json({ error: `GitHub API ${res.status}` }, 502);
    }

    const release = await res.json();
    const asset = (release.assets || []).find((a) => a.name.endsWith('.apk'));
    if (!asset) return json({ error: 'No APK asset yet' }, 503);

    const match = asset.name.match(/v(\d+(?:\.\d+)*)/);
    return json(
      {
        version: match ? match[1] : null,
        filename: asset.name,
        size_bytes: asset.size,
        updated_at: asset.updated_at,
        download_url: asset.browser_download_url,
      },
      200,
      // 5-min CDN cache is fine for a version badge.
      'public, max-age=300'
    );
  } catch (err) {
    return json({ error: err.message }, 500);
  }
}

function json(body, status = 200, cacheControl = 'no-store') {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': cacheControl,
    },
  });
}

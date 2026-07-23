// Vercel Edge Function — resolves the latest release and 302-redirects the
// browser straight to the GitHub CDN asset.
//
// Why redirect instead of streaming the bytes through this function: a streamed
// Response drops Content-Length (it goes out chunked), so the browser shows an
// "unknown size" (?) and no download progress. GitHub's CDN serves the APK with
// a correct Content-Length, so redirecting gives the user a real size + progress
// bar. The release lookup is no-store, so the redirect always points at the
// newest `latest` build.
export const config = { runtime: 'edge' };

const REPO = 'adonisdamson/vanguard';

export default async function handler() {
  try {
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
    const asset = (release.assets || []).find((a) => a.name.endsWith('.apk'));
    if (!asset) {
      return new Response('APK not available yet — check back shortly.', {
        status: 503,
        headers: { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' },
      });
    }

    // 302 to the CDN — browser downloads directly with size + progress.
    return new Response(null, {
      status: 302,
      headers: {
        Location: asset.browser_download_url,
        'Cache-Control': 'no-store, no-cache, must-revalidate',
        Pragma: 'no-cache',
      },
    });
  } catch (err) {
    return new Response(`Error: ${err.message}`, {
      status: 500,
      headers: { 'Cache-Control': 'no-store' },
    });
  }
}

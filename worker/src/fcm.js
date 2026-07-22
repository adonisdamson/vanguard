// Push notifications via FCM HTTP v1 — Workers-native replacement for
// firebase-admin (which is Node-only). We mint a short-lived OAuth2 access
// token by signing a JWT with the service account key using Web Crypto (RS256),
// then POST the message to the FCM v1 endpoint.
//
// Configure by setting FIREBASE_SERVICE_ACCOUNT (the service account JSON, as a
// single-line secret). If unset, sendToTopic silently no-ops — same behaviour
// as before.

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

// Cached access token, scoped to the isolate. Refreshed shortly before expiry.
let _token = null; // { accessToken, expiresAt }

function b64url(input) {
  // input: string or ArrayBuffer/Uint8Array → base64url (no padding)
  let bytes;
  if (typeof input === 'string') {
    bytes = new TextEncoder().encode(input);
  } else {
    bytes = new Uint8Array(input);
  }
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der.buffer;
}

async function signJwt(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claim))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${b64url(sig)}`;
}

async function getAccessToken(sa) {
  if (_token && Date.now() < _token.expiresAt - 60_000) return _token.accessToken;

  const assertion = await signJwt(sa);
  const resp = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!resp.ok) {
    throw new Error(`OAuth token exchange failed: ${resp.status} ${await resp.text()}`);
  }
  const json = await resp.json();
  _token = {
    accessToken: json.access_token,
    expiresAt: Date.now() + (json.expires_in ?? 3600) * 1000,
  };
  return _token.accessToken;
}

/**
 * Send a push notification to a Firebase topic.
 * Silently no-ops if FIREBASE_SERVICE_ACCOUNT is not configured.
 */
export async function sendToTopic(env, topic, { title, body, data = {} }) {
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return;

  let sa;
  try {
    sa = typeof raw === 'string' ? JSON.parse(raw) : raw;
  } catch (err) {
    console.error('[FCM] Invalid FIREBASE_SERVICE_ACCOUNT JSON:', err.message);
    return;
  }

  try {
    const accessToken = await getAccessToken(sa);
    // FCM v1 requires string values in the data map.
    const stringData = {};
    for (const [k, v] of Object.entries(data)) stringData[k] = String(v);

    const resp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            topic,
            notification: { title, body },
            data: stringData,
            android: { priority: 'high' },
          },
        }),
      },
    );
    if (!resp.ok) {
      console.error('[FCM] send error:', resp.status, await resp.text());
    }
  } catch (err) {
    // Non-fatal — log but don't crash the request.
    console.error('[FCM] sendToTopic error:', err.message);
  }
}

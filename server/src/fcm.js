const admin = require('firebase-admin');

let _initialized = false;

function getMessaging() {
  if (!_initialized) {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccount) return null;
    try {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccount)),
      });
      _initialized = true;
    } catch (err) {
      console.error('[FCM] Failed to initialize firebase-admin:', err.message);
      return null;
    }
  }
  return admin.messaging();
}

/**
 * Send a push notification to a Firebase topic.
 * Silently no-ops if FIREBASE_SERVICE_ACCOUNT is not configured.
 */
async function sendToTopic(topic, { title, body, data = {} }) {
  const messaging = getMessaging();
  if (!messaging) return;
  try {
    await messaging.send({
      topic,
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });
  } catch (err) {
    // Non-fatal — log but don't crash the request
    console.error('[FCM] sendToTopic error:', err.message);
  }
}

module.exports = { sendToTopic };

import {AccessToken} from 'livekit-server-sdk';
import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const LIVEKIT_URL = process.env.LIVEKIT_URL || '';
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || '';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || '';

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Authorization,Content-Type',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

async function verifyFirebaseToken(event) {
  const auth = event.headers?.authorization || event.headers?.Authorization || '';
  const match = auth.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error('Missing bearer token');
  return admin.auth().verifyIdToken(match[1]);
}

export const handler = async (event) => {
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return response(204, {});
  }
  try {
    await verifyFirebaseToken(event);
    const path = event.rawPath || '';
    const body = event.body ? JSON.parse(event.body) : {};

    if (path.endsWith('/livekit/token')) {
      const roomName = (body.roomName || '').trim();
      const identity = (body.identity || '').trim();
      const participantName = (body.participantName || '').trim();
      if (!roomName || !identity || !participantName) {
        return response(400, {error: 'roomName, identity, participantName are required'});
      }
      const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
        identity,
        name: participantName,
        ttl: '1h',
      });
      token.addGrant({
        roomJoin: true,
        room: roomName,
        canPublish: true,
        canSubscribe: true,
      });
      return response(200, {serverUrl: LIVEKIT_URL, token: await token.toJwt()});
    }

    if (path.endsWith('/call/session/start')) {
      // TODO: send FCM push notification using callee's stored token.
      // Keep successful response so app call flow continues.
      return response(200, {ok: true});
    }

    return response(404, {error: 'Route not found'});
  } catch (error) {
    return response(401, {error: error.message || 'Unauthorized'});
  }
};

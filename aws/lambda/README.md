# AWS Lambda Backend (LiveKit + Call Events)

Use this Lambda when you want AWS instead of Firebase Functions for call infrastructure.

## Endpoints expected by the app

- `POST /livekit/token`
  - body: `{ roomName, identity, participantName }`
  - returns: `{ serverUrl, token }`
- `POST /call/session/start`
  - body: `{ callId, callerUid, calleeUid, callerRole, roomName }`
  - returns: `{ ok: true }`

Both endpoints must accept Firebase ID token in `Authorization: Bearer <token>`.

## Configure app to use Lambda

Run/build Flutter with:

`--dart-define=CLOUD_API_BASE_URL=https://<your-api-id>.execute-api.<region>.amazonaws.com`

The app already tries both route styles:
- `/livekit/token` (AWS style)
- `/livekitToken` (Firebase fallback)
- `/call/session/start` (AWS style)
- `/callSessionStart` (Firebase fallback)

## Lambda environment variables

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

## Notifications

Implement FCM send logic inside `/call/session/start` route in Lambda
using `calleeUid` -> token lookup (Firestore or your user DB).

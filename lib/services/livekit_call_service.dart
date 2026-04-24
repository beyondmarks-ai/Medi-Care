import 'package:livekit_client/livekit_client.dart';
import 'package:medicare_ai/services/api_key_store.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class LiveKitCallService {
  LiveKitCallService._();

  static String buildRoomName({
    required String patientId,
    required String doctorId,
  }) {
    return 'medicare_${doctorId}_$patientId';
  }

  static String get serverUrl => ApiKeyStore.read('LIVEKIT_URL');
  static String get apiKey => ApiKeyStore.read('LIVEKIT_API_KEY');
  static String get apiSecret => ApiKeyStore.read('LIVEKIT_API_SECRET');

  static bool get isConfigured =>
      serverUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      apiSecret.trim().isNotEmpty;

  static String buildAccessToken({
    required String roomName,
    required String identity,
    required String participantName,
  }) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwt = JWT(
      <String, dynamic>{
        'iss': apiKey,
        'sub': identity,
        'name': participantName,
        'nbf': nowSeconds - 5,
        'exp': nowSeconds + (60 * 60),
        'video': <String, dynamic>{
          'roomJoin': true,
          'room': roomName,
          'canPublish': true,
          'canSubscribe': true,
        },
      },
    );
    return jwt.sign(
      SecretKey(apiSecret),
      algorithm: JWTAlgorithm.HS256,
    );
  }

  static Future<void> connectAudio({
    required Room room,
    required String roomName,
    required String identity,
    required String participantName,
  }) async {
    if (!isConfigured) {
      throw StateError(
          'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET.');
    }
    final token = buildAccessToken(
      roomName: roomName,
      identity: identity,
      participantName: participantName,
    );

    await room.connect(
      serverUrl,
      token,
      fastConnectOptions: FastConnectOptions(
        microphone: TrackOption(enabled: true),
      ),
    );
    await room.localParticipant?.setMicrophoneEnabled(true);
  }
}

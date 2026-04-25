import 'package:livekit_client/livekit_client.dart';
import 'package:medicare_ai/services/cloud_backend_service.dart';

class LiveKitCallService {
  LiveKitCallService._();

  static String buildRoomName({
    required String patientId,
    required String doctorId,
  }) {
    return 'medicare_${doctorId}_$patientId';
  }

  static bool get isConfigured => true;

  static Future<Map<String, String>> fetchJoinCredentials({
    required String roomName,
    required String identity,
    required String participantName,
  }) async {
    final response = await CloudBackendService.postJsonWithFallback(
      paths: const <String>[
        '/livekit/token',
        '/livekitToken',
      ],
      body: <String, dynamic>{
        'roomName': roomName,
        'identity': identity,
        'participantName': participantName,
      },
    );
    final serverUrl = (response['serverUrl'] as String?)?.trim() ?? '';
    final token = (response['token'] as String?)?.trim() ?? '';
    if (serverUrl.isEmpty || token.isEmpty) {
      throw StateError('LiveKit token service returned invalid response.');
    }
    return <String, String>{
      'serverUrl': serverUrl,
      'token': token,
    };
  }

  static Future<void> connectAudio({
    required Room room,
    required String roomName,
    required String identity,
    required String participantName,
  }) async {
    final creds = await fetchJoinCredentials(
      roomName: roomName,
      identity: identity,
      participantName: participantName,
    );
    final serverUrl = creds['serverUrl']!;
    final token = creds['token']!;

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

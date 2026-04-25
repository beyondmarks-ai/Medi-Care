import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicare_ai/services/cloud_backend_service.dart';

class CallSessionService {
  CallSessionService._();

  static final CallSessionService instance = CallSessionService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingSessionStream({
    required String calleeUid,
  }) {
    return _db
        .collection('calls')
        .where('calleeUid', isEqualTo: calleeUid)
        .where('status', isEqualTo: 'started')
        .snapshots();
  }

  Future<String> createSession({
    required String callerUid,
    required String calleeUid,
    required String callerRole,
    required String roomName,
  }) async {
    final doc = await _db.collection('calls').add(<String, dynamic>{
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'callerRole': callerRole,
      'roomName': roomName,
      'status': 'started',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'recordingUrl': null,
    });
    try {
      await CloudBackendService.postJsonWithFallback(
        paths: const <String>[
          '/call/session/start',
          '/callSessionStart',
        ],
        body: <String, dynamic>{
          'callId': doc.id,
          'callerUid': callerUid,
          'calleeUid': calleeUid,
          'callerRole': callerRole,
          'roomName': roomName,
        },
      );
    } catch (_) {
      // Keep call creation functional even if notification webhook fails.
    }
    return doc.id;
  }

  Future<void> endSession({
    required String callId,
    String? recordingUrl,
  }) async {
    await _db.collection('calls').doc(callId).set(
      <String, dynamic>{
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'recordingUrl': recordingUrl,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateStatus({
    required String callId,
    required String status,
  }) async {
    await _db.collection('calls').doc(callId).set(
      <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class CallSessionService {
  CallSessionService._();

  static final CallSessionService instance = CallSessionService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
}

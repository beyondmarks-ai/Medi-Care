import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseProfileService {
  FirebaseProfileService._();

  static final FirebaseProfileService instance = FirebaseProfileService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _assignments => _db.collection('assignments');

  Future<void> upsertUserProfile({
    required String uid,
    required String role,
    required String uniqueId,
    required String name,
    required String email,
    String? phone,
    String? specialization,
    String? assignedDoctorId,
    String? assignedDoctorName,
  }) async {
    await _users.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'role': role,
        'uniqueId': uniqueId,
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'specialization': specialization ?? '',
        'assignedDoctorId': assignedDoctorId ?? '',
        'assignedDoctorName': assignedDoctorName ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    final result = await _users.where('role', isEqualTo: 'doctor').get();
    return result.docs
        .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
        .toList(growable: false);
  }

  Future<void> createAssignment({
    required String patientUid,
    required String patientId,
    required String doctorUid,
    required String doctorId,
  }) async {
    final assignmentId = '${doctorId}_$patientId';
    await _assignments.doc(assignmentId).set(
      <String, dynamic>{
        'patientUid': patientUid,
        'patientId': patientId,
        'doctorUid': doctorUid,
        'doctorId': doctorId,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<Map<String, dynamic>>> assignmentsForDoctor(String doctorUid) async {
    final result = await _assignments.where('doctorUid', isEqualTo: doctorUid).get();
    return result.docs
        .map((d) => d.data())
        .where((row) => (row['active'] as bool?) ?? true)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> assignmentForPatient(String patientUid) async {
    final result = await _assignments.where('patientUid', isEqualTo: patientUid).get();
    if (result.docs.isEmpty) return null;
    final activeRows = result.docs
        .map((d) => d.data())
        .where((row) => (row['active'] as bool?) ?? true)
        .toList(growable: false);
    if (activeRows.isEmpty) return null;
    activeRows.sort((a, b) {
      final aTs = a['updatedAt'];
      final bTs = b['updatedAt'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      if (bTs is Timestamp) return 1;
      if (aTs is Timestamp) return -1;
      return 0;
    });
    return activeRows.first;
  }

  Future<void> deactivateAssignmentsForPatient(String patientUid) async {
    final result = await _assignments.where('patientUid', isEqualTo: patientUid).get();
    final batch = _db.batch();
    for (final doc in result.docs) {
      final data = doc.data();
      final isActive = (data['active'] as bool?) ?? true;
      if (!isActive) continue;
      batch.update(
        doc.reference,
        <String, dynamic>{
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  Future<void> updatePatientAssignedDoctor({
    required String patientUid,
    required String doctorId,
    required String doctorName,
  }) async {
    await _users.doc(patientUid).set(
      <String, dynamic>{
        'assignedDoctorId': doctorId,
        'assignedDoctorName': doctorName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

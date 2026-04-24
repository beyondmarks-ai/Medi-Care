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
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<Map<String, dynamic>>> assignmentsForDoctor(String doctorUid) async {
    final result = await _assignments.where('doctorUid', isEqualTo: doctorUid).get();
    return result.docs.map((d) => d.data()).toList(growable: false);
  }

  Future<Map<String, dynamic>?> assignmentForPatient(String patientUid) async {
    final result = await _assignments.where('patientUid', isEqualTo: patientUid).limit(1).get();
    if (result.docs.isEmpty) return null;
    return result.docs.first.data();
  }
}

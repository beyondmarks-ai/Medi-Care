import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:medicare_ai/services/firebase_profile_service.dart';

class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.name,
    required this.specialization,
    required this.avatarColor,
  });

  final String id;
  final String name;
  final String specialization;
  final Color avatarColor;
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.assignedDoctorId,
    required this.condition,
  });

  final String id;
  final String name;
  final String phone;
  final String assignedDoctorId;
  final String condition;
}

class CareAssignmentService {
  CareAssignmentService._();

  static final CareAssignmentService instance = CareAssignmentService._();
  static final Random _random = Random();

  final Map<String, DoctorProfile> _doctors = <String, DoctorProfile>{};
  final Map<String, PatientProfile> _patients = <String, PatientProfile>{};
  final Map<String, String> _doctorUidById = <String, String>{};
  final Map<String, String> _doctorIdByUid = <String, String>{};
  final Map<String, String> _patientUidById = <String, String>{};
  final Map<String, String> _patientIdByUid = <String, String>{};

  String? _activePatientId;
  String? _activeDoctorId;
  int _doctorSeq = 200;

  String generateUniquePatientId() {
    while (true) {
      final id = 'MED${_random.nextInt(1000).toString().padLeft(3, '0')}';
      if (!_patients.containsKey(id)) return id;
    }
  }

  Future<DoctorProfile> assignDoctorToPatient({
    required String patientId,
    required String patientUid,
    required String patientName,
    required String patientPhone,
  }) async {
    final doctors = _doctors.values.toList(growable: false);
    if (doctors.isEmpty) {
      throw StateError('No doctor is available yet. Create a doctor account first.');
    }
    doctors.sort((a, b) => _patientsForDoctorCount(a.id) - _patientsForDoctorCount(b.id));
    final lowestLoad = _patientsForDoctorCount(doctors.first.id);
    final candidates =
        doctors.where((d) => _patientsForDoctorCount(d.id) == lowestLoad).toList(growable: false);
    final doctor = candidates[_random.nextInt(candidates.length)];

    _patients[patientId] = PatientProfile(
      id: patientId,
      name: patientName.trim().isEmpty ? 'Patient $patientId' : patientName.trim(),
      phone: patientPhone.trim().isEmpty ? '+91 90000 00000' : patientPhone.trim(),
      assignedDoctorId: doctor.id,
      condition: 'Newly onboarded patient',
    );
    _patientUidById[patientId] = patientUid;
    _patientIdByUid[patientUid] = patientId;
    _doctorUidById.putIfAbsent(doctor.id, () => doctor.id);
    _doctorIdByUid.putIfAbsent(doctor.id, () => doctor.id);
    await FirebaseProfileService.instance.createAssignment(
      patientUid: patientUid,
      patientId: patientId,
      doctorUid: doctor.id,
      doctorId: doctor.id,
    );
    return doctor;
  }

  Future<DoctorProfile> registerDoctorFromSignup({
    required String uid,
    required String doctorName,
    required String specialization,
  }) async {
    _doctorSeq += 1;
    final id = 'DOC$_doctorSeq';
    final doctor = DoctorProfile(
      id: id,
      name: doctorName.trim().isEmpty ? 'Dr. New Doctor' : doctorName.trim(),
      specialization: specialization.trim().isEmpty ? 'General Medicine' : specialization.trim(),
      avatarColor: const Color(0xFF6A7BFF),
    );
    _doctors[id] = doctor;
    _doctorUidById[id] = uid;
    _doctorIdByUid[uid] = id;
    return doctor;
  }

  void upsertDoctorProfile({
    required String doctorId,
    required String uid,
    required String name,
    required String specialization,
  }) {
    _doctors[doctorId] = DoctorProfile(
      id: doctorId,
      name: name.isEmpty ? 'Doctor' : name,
      specialization: specialization.isEmpty ? 'General Medicine' : specialization,
      avatarColor: const Color(0xFF6A7BFF),
    );
    _doctorUidById[doctorId] = uid;
    _doctorIdByUid[uid] = doctorId;
  }

  int _patientsForDoctorCount(String doctorId) =>
      _patients.values.where((p) => p.assignedDoctorId == doctorId).length;

  void setActivePatient(String patientId) => _activePatientId = patientId;
  void setActiveDoctor(String doctorId) => _activeDoctorId = doctorId;

  String? get activePatientUid =>
      _activePatientId == null ? null : _patientUidById[_activePatientId];
  String? get activeDoctorUid =>
      _activeDoctorId == null ? null : _doctorUidById[_activeDoctorId];

  PatientProfile? get activePatient =>
      _activePatientId == null ? null : _patients[_activePatientId];

  DoctorProfile? get activeDoctor =>
      _activeDoctorId == null ? null : _doctors[_activeDoctorId];

  List<PatientProfile> patientsForDoctor(String doctorId) => _patients.values
      .where((p) => p.assignedDoctorId == doctorId)
      .toList(growable: false);

  Future<void> hydrateDoctorPatients(String doctorUid) async {
    final assignments = await FirebaseProfileService.instance.assignmentsForDoctor(doctorUid);
    for (final row in assignments) {
      final patientUid = (row['patientUid'] as String?) ?? '';
      final patientId = (row['patientId'] as String?) ?? '';
      final doctorId = (row['doctorId'] as String?) ?? '';
      if (patientUid.isEmpty || patientId.isEmpty || doctorId.isEmpty) continue;
      _patientUidById[patientId] = patientUid;
      _patientIdByUid[patientUid] = patientId;
      _doctorUidById[doctorId] = doctorUid;
      _doctorIdByUid[doctorUid] = doctorId;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(patientUid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      _patients[patientId] = PatientProfile(
        id: patientId,
        name: (data['name'] as String?) ?? 'Patient $patientId',
        phone: (data['phone'] as String?) ?? '+91 90000 00000',
        assignedDoctorId: doctorId,
        condition: (data['condition'] as String?) ?? 'General follow-up',
      );
    }
  }

  Future<void> hydratePatientAssignment(String patientUid) async {
    final row = await FirebaseProfileService.instance.assignmentForPatient(patientUid);
    if (row == null) return;
    final patientId = (row['patientId'] as String?) ?? '';
    final doctorUid = (row['doctorUid'] as String?) ?? '';
    final doctorId = (row['doctorId'] as String?) ?? '';
    if (patientId.isEmpty || doctorId.isEmpty) return;
    _patientUidById[patientId] = patientUid;
    _patientIdByUid[patientUid] = patientId;
    _doctorUidById[doctorId] = doctorUid;
    _doctorIdByUid[doctorUid] = doctorId;
    _activePatientId = patientId;
  }

  DoctorProfile? doctorById(String doctorId) => _doctors[doctorId];
  String? doctorUidById(String doctorId) => _doctorUidById[doctorId];
  String? patientUidById(String patientId) => _patientUidById[patientId];

  bool canPatientCallDoctor({
    required String patientId,
    required String doctorId,
  }) {
    final patient = _patients[patientId];
    if (patient == null) return false;
    return patient.assignedDoctorId == doctorId;
  }

  bool canDoctorCallPatient({
    required String doctorId,
    required String patientId,
  }) {
    final patient = _patients[patientId];
    if (patient == null) return false;
    return patient.assignedDoctorId == doctorId;
  }
}

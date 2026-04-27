import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/doctor_send_pharmacy_screen.dart';
import 'package:medicare_ai/screens/live_call_screen.dart';
import 'package:medicare_ai/screens/login_screen.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/incoming_call_listener.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key, this.doctorId, this.doctorName});

  final String? doctorId;
  final String? doctorName;

  @override
  Widget build(BuildContext context) {
    final doctor = _currentDoctor();
    return IncomingCallListener(
      currentRole: 'doctor',
      participantName: doctorName ?? doctor.name,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildHero(context),
                const SizedBox(height: 16),
                _buildPrescriptionAction(context),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Assigned patients'),
                const SizedBox(height: 12),
                ..._assignedPatientsForCurrentDoctor().map(
                  (patient) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssignedPatientTile(
                      patient: patient,
                      onTap: () => _showPatientDetailsSheet(context, patient),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = context.medicareColorScheme;
    final doctor = _currentDoctor();
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
          child: Icon(Icons.local_hospital_rounded, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctorName ?? doctor.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${doctor.id} · ${doctor.specialization}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
        const ThemeModeIconButton(),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Sign out',
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final px = context.portalX;
    final doctor = _currentDoctor();
    final count = CareAssignmentService.instance
        .patientsForDoctor(doctor.id)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [px.ctaStart, px.ctaEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome, Doctor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1 ? '1 assigned patient' : '$count assigned patients',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review assigned patients, start secure calls, and prepare pharmacy prescriptions.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionAction(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DoctorSendPharmacyScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medication_liquid_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create prescription',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build a draft with multiple medicines and send it to a patient cart.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: context.medicareColorScheme.onSurface,
      ),
    );
  }

  DoctorProfile _currentDoctor() {
    final service = CareAssignmentService.instance;
    final byId = doctorId == null ? null : service.doctorById(doctorId!);
    final active = service.activeDoctor;
    return byId ??
        active ??
        const DoctorProfile(
          id: 'DOC101',
          name: 'Dr. Mehta',
          specialization: 'Cardiology',
          avatarColor: Color(0xFF916CF2),
        );
  }

  List<_AssignedPatient> _assignedPatientsForCurrentDoctor() {
    final service = CareAssignmentService.instance;
    final doctor = _currentDoctor();
    final patients = service.patientsForDoctor(doctor.id);
    if (patients.isEmpty) {
      return const [
        _AssignedPatient(
          name: 'No assigned patient yet',
          patientId: '---',
          phone: 'Waiting for assignment',
          condition: 'New doctor onboarding',
          avatarColor: Color(0xFF9CA3AF),
        ),
      ];
    }
    return patients
        .map(
          (p) => _AssignedPatient(
            name: p.name,
            patientId: p.id,
            phone: p.phone,
            condition: p.condition,
            avatarColor: doctor.avatarColor,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showPatientDetailsSheet(
    BuildContext context,
    _AssignedPatient patient,
  ) async {
    final cs = context.medicareColorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 38,
                backgroundColor: patient.avatarColor.withValues(alpha: 0.18),
                child: Text(
                  patient.initials,
                  style: TextStyle(
                    color: patient.avatarColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                patient.name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Patient ID: ${patient.patientId}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Condition: ${patient.condition}',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: patient.patientId == '---'
                      ? null
                      : () => _callPatientInApp(context, patient),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call in app'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (patient.patientId != '---') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      final pre = CareAssignmentService.instance.patientById(
                        patient.patientId,
                      );
                      Navigator.of(sheetContext).pop();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DoctorSendPharmacyScreen(preSelectedPatient: pre),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Send to pharmacy cart'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _callPatientInApp(
    BuildContext context,
    _AssignedPatient patient,
  ) async {
    final doctor = _currentDoctor();
    final allowed = CareAssignmentService.instance.canDoctorCallPatient(
      doctorId: doctor.id,
      patientId: patient.patientId,
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only assigned patients can be called.')),
      );
      return;
    }

    final roomName = LiveKitCallService.buildRoomName(
      patientId: patient.patientId,
      doctorId: doctor.id,
    );
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final patientUid =
        CareAssignmentService.instance.patientUidById(patient.patientId) ?? '';
    if (myUid.isEmpty || patientUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call mapping not ready yet. Please refresh.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveCallScreen(
          roomName: roomName,
          headerTitle: 'Call with ${patient.name}',
          callerUid: myUid,
          calleeUid: patientUid,
          callerRole: 'doctor',
          participantName: doctor.name,
        ),
      ),
    );
  }
}

class _AssignedPatient {
  const _AssignedPatient({
    required this.name,
    required this.patientId,
    required this.phone,
    required this.condition,
    required this.avatarColor,
  });

  final String name;
  final String patientId;
  final String phone;
  final String condition;
  final Color avatarColor;

  String get initials {
    final parts = name.split(' ');
    final first = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first.substring(0, 1)
        : 'P';
    final second = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last.substring(0, 1)
        : '';
    return '$first$second';
  }
}

class _AssignedPatientTile extends StatelessWidget {
  const _AssignedPatientTile({required this.patient, required this.onTap});

  final _AssignedPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: patient.avatarColor.withValues(alpha: 0.16),
                child: Text(
                  patient.initials,
                  style: TextStyle(
                    color: patient.avatarColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${patient.patientId} • ${patient.phone}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

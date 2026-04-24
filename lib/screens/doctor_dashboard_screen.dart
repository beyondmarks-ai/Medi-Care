import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/live_call_screen.dart';
import 'package:medicare_ai/screens/login_screen.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({
    super.key,
    this.doctorId,
    this.doctorName,
  });

  final String? doctorId;
  final String? doctorName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildHero(context),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Today at a glance'),
              const SizedBox(height: 12),
              _buildMetricRow(context),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Priority queue'),
              const SizedBox(height: 12),
              _DoctorTaskTile(
                icon: Icons.monitor_heart_outlined,
                title: 'High-risk vitals alert',
                subtitle: 'Rajat S. - BP trend above baseline',
                action: 'Review now',
              ),
              const SizedBox(height: 10),
              _DoctorTaskTile(
                icon: Icons.assignment_rounded,
                title: 'Pending report sign-off',
                subtitle: '3 lab reports need validation',
                action: 'Open reports',
              ),
              const SizedBox(height: 10),
              _DoctorTaskTile(
                icon: Icons.video_call_rounded,
                title: 'Teleconsultation in 20 min',
                subtitle: 'Neha P. - follow-up consultation',
                action: 'Prepare',
              ),
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
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
          ),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Doctor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '12 patients waiting for review',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Prioritize urgent flags, approve reports, and complete consults.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MetricCard(label: 'Consults', value: '8', icon: Icons.groups_rounded),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: 'Alerts', value: '3', icon: Icons.warning_amber_rounded),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: 'Reports', value: '5', icon: Icons.description_rounded),
        ),
      ],
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
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
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
    final doctorUid = CareAssignmentService.instance.activeDoctorUid ?? '';
    final patientUid = CareAssignmentService.instance.patientUidById(patient.patientId) ?? '';
    if (doctorUid.isEmpty || patientUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call mapping not ready yet. Please refresh.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveCallScreen(
          roomName: roomName,
          headerTitle: 'Call with ${patient.name}',
          callerUid: doctorUid,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorTaskTile extends StatelessWidget {
  const _DoctorTaskTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: Text(action)),
        ],
      ),
    );
  }
}

class _AssignedPatientTile extends StatelessWidget {
  const _AssignedPatientTile({
    required this.patient,
    required this.onTap,
  });

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

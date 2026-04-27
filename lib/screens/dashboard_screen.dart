import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medicare_ai/screens/live_call_screen.dart';
import 'package:medicare_ai/screens/login_screen.dart';
import 'package:medicare_ai/screens/condition_reference_screen.dart';
import 'package:medicare_ai/screens/medical_ai_chat_screen.dart';
import 'package:medicare_ai/screens/medicine_scanner_screen.dart';
import 'package:medicare_ai/screens/pharmacy_store_screen.dart';
import 'package:medicare_ai/services/app_log_service.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/firebase_auth_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/emergency_dock.dart';
import 'package:medicare_ai/widgets/incoming_call_listener.dart';
import 'package:medicare_ai/widgets/patient_pharmacy_inbox_listener.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.patientId,
    this.patientName,
    this.assignedDoctor,
    this.assignedDoctorId,
  });

  final String? patientId;
  final String? patientName;
  final String? assignedDoctor;
  final String? assignedDoctorId;

  @override
  Widget build(BuildContext context) {
    return IncomingCallListener(
      currentRole: 'patient',
      participantName: patientId == null ? 'Patient' : 'Patient $patientId',
      child: PatientPharmacyInboxListener(
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(context)),
                      SliverToBoxAdapter(child: _buildGreeting(context)),
                      if (patientId != null && assignedDoctor != null)
                        SliverToBoxAdapter(
                          child: _buildPatientIdentityCard(context),
                        ),
                      SliverToBoxAdapter(child: _buildHeroCard(context)),
                      SliverToBoxAdapter(
                        child: _buildSectionTitle(context, 'Quick actions'),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 1.15,
                              ),
                          delegate: SliverChildListDelegate(
                            _quickActionCards(context),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
                const Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: EmergencyDock(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _quickActionCards(BuildContext context) {
    final t = _actionTints(context);
    return [
      _QuickActionCard(
        icon: Icons.document_scanner_rounded,
        label: 'Scan medicine',
        subtitle: 'Camera label check',
        tint: t[0],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const MedicineScannerScreen(),
            ),
          );
        },
      ),
      _QuickActionCard(
        icon: Icons.psychology_rounded,
        label: 'AI health coach',
        subtitle: 'Guidance & triage',
        tint: t[1],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const MedicalAiChatScreen(),
            ),
          );
        },
      ),
      _QuickActionCard(
        icon: Icons.medication_liquid_rounded,
        label: 'Medication',
        subtitle: 'Condition reference (education)',
        tint: t[2],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const ConditionReferenceScreen(),
            ),
          );
        },
      ),
      _QuickActionCard(
        icon: Icons.local_pharmacy_rounded,
        label: 'Pharmacy',
        subtitle: 'Browse medicines and cart',
        tint: t[3],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const PharmacyStoreScreen(),
            ),
          );
        },
      ),
    ];
  }

  static List<Color> _actionTints(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const [
        Color(0xFF2A2338),
        Color(0xFF1E2A32),
        Color(0xFF1E2A24),
        Color(0xFF2A2620),
      ];
    }
    return const [
      Color(0xFFF0EBFF),
      Color(0xFFE8F4FC),
      Color(0xFFF2F8EE),
      Color(0xFFFFF4E5),
    ];
  }

  Widget _buildHeader(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Medicare AI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Health Portal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ThemeModeIconButton(),
              const SizedBox(width: 8),
              _circleIconButton(context, Icons.logout_rounded, () async {
                await FirebaseAuthService.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    final cs = context.medicareColorScheme;
    return Material(
      color: cs.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          width: 48,
          child: Icon(icon, color: cs.onSurface, size: 22),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final cs = context.medicareColorScheme;
    final salute = _timeSalute();
    final displayName = _patientDisplayName();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$salute, $displayName',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access your doctor, pharmacy cart, medication reference, and AI health coach from one place.',
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _timeSalute() {
    final hour = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    ).hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _patientDisplayName() {
    final explicit = patientName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fromCache = patientId == null
        ? null
        : CareAssignmentService.instance.patientById(patientId!);
    final cachedName = fromCache?.name.trim();
    if (cachedName != null && cachedName.isNotEmpty) return cachedName;
    if (patientId != null && patientId!.trim().isNotEmpty) return 'Patient $patientId';
    return 'Patient';
  }

  Widget _buildHeroCard(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Care hub',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.trending_up_rounded,
                  color: cs.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              assignedDoctor == null ? 'Get started' : 'Connected care',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              assignedDoctor == null
                  ? 'Choose your doctor and keep your health tools close.'
                  : 'Assigned to $assignedDoctor. Use the actions below for care support.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const PharmacyStoreScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Open pharmacy',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientIdentityCard(BuildContext context) {
    final cs = context.medicareColorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1B2A23) : const Color(0xFFEFFFF4);
    final border = dark ? const Color(0xFF3D8B64) : const Color(0xFF78C593);
    final accent = dark ? const Color(0xFF8DE3B1) : const Color(0xFF1D7F45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_user_rounded,
              color: accent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient ID: ${patientId!}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Assigned Doctor: ${assignedDoctor!}',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _startInAppDoctorCall(context),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call assigned doctor in app'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _chooseDoctorFromDashboard(context),
                    icon: const Icon(Icons.local_hospital_rounded),
                    label: const Text('Choose / Change doctor'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startInAppDoctorCall(BuildContext context) {
    if (patientId == null || assignedDoctorId == null) return;
    final allowed = CareAssignmentService.instance.canPatientCallDoctor(
      patientId: patientId!,
      doctorId: assignedDoctorId!,
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only your assigned doctor can be called.'),
        ),
      );
      return;
    }
    final roomName = LiveKitCallService.buildRoomName(
      patientId: patientId!,
      doctorId: assignedDoctorId!,
    );
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorUid =
        CareAssignmentService.instance.doctorUidById(assignedDoctorId!) ?? '';
    if (myUid.isEmpty || doctorUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call mapping not ready yet. Please re-login.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveCallScreen(
          roomName: roomName,
          headerTitle: 'Calling $assignedDoctor',
          callerUid: myUid,
          calleeUid: doctorUid,
          callerRole: 'patient',
          participantName: 'Patient ${patientId!}',
        ),
      ),
    );
  }

  Future<void> _chooseDoctorFromDashboard(BuildContext context) async {
    if (patientId == null || patientId!.trim().isEmpty) return;
    final chosen = await showModalBottomSheet<DoctorProfile>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _DoctorPickerSheet(
        doctorsFuture: CareAssignmentService.instance.availableDoctors(),
      ),
    );
    if (!context.mounted) return;
    if (chosen == null) return;
    final patientUid = FirebaseAuth.instance.currentUser?.uid;
    if (patientUid == null || patientUid.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to change doctor.')),
      );
      return;
    }
    try {
      final updated = await CareAssignmentService.instance
          .reassignPatientToDoctor(
            patientUid: patientUid,
            patientId: patientId!,
            doctorId: chosen.id,
          );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(
            patientId: patientId,
            patientName: patientName,
            assignedDoctor: updated.name,
            assignedDoctorId: updated.id,
          ),
        ),
      );
    } catch (e) {
      AppLogService.instance.error('Failed to change assigned doctor', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change doctor: $e')));
    }
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.medicareColorScheme.onSurface,
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.primary, size: 24),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorPickerSheet extends StatelessWidget {
  const _DoctorPickerSheet({required this.doctorsFuture});

  final Future<List<DoctorProfile>> doctorsFuture;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: FutureBuilder<List<DoctorProfile>>(
          future: doctorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'Unable to load doctors.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            final doctors = snapshot.data ?? const <DoctorProfile>[];
            if (doctors.isEmpty) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'No doctors available yet.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Doctor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: doctors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: cs.surfaceContainerHighest,
                        leading: CircleAvatar(
                          backgroundColor: doctor.avatarColor.withValues(
                            alpha: 0.2,
                          ),
                          child: Icon(Icons.person, color: doctor.avatarColor),
                        ),
                        title: Text(doctor.name),
                        subtitle: Text(
                          '${doctor.id} • ${doctor.specialization}',
                        ),
                        onTap: () => Navigator.of(context).pop(doctor),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

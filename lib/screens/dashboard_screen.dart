import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medicare_ai/screens/app_logs_screen.dart';
import 'package:medicare_ai/screens/live_call_screen.dart';
import 'package:medicare_ai/screens/login_screen.dart';
import 'package:medicare_ai/screens/medical_ai_chat_screen.dart';
import 'package:medicare_ai/services/app_log_service.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/firebase_auth_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/emergency_dock.dart';
import 'package:medicare_ai/widgets/incoming_call_listener.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

const _success = Color(0xFF58B95E);
const _danger = Color(0xFFFF4949);
const _primary = Color(0xFF916CF2);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.patientId,
    this.assignedDoctor,
    this.assignedDoctorId,
  });

  final String? patientId;
  final String? assignedDoctor;
  final String? assignedDoctorId;

  @override
  Widget build(BuildContext context) {
    return IncomingCallListener(
      currentRole: 'patient',
      participantName: patientId == null ? 'Patient' : 'Patient $patientId',
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
                    SliverToBoxAdapter(child: _buildPatientIdentityCard(context)),
                  SliverToBoxAdapter(child: _buildHeroCard(context)),
                  SliverToBoxAdapter(child: _buildSectionTitle(context, 'Quick actions')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  SliverToBoxAdapter(child: _buildSectionTitle(context, 'Today')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _TimelineTile(
                            title: 'Vitals in range',
                            subtitle: 'Last synced from wearable · 2h ago',
                            leading: Icons.favorite_rounded,
                            leadingBg: _tileLeadBg(context, 0),
                            leadingColor: _danger,
                          ),
                          const SizedBox(height: 10),
                          _TimelineTile(
                            title: 'Follow-up: Dr. Mehta',
                            subtitle: 'Cardiology · Tomorrow 10:30 AM',
                            leading: Icons.event_available_rounded,
                            leadingBg: _tileLeadBg(context, 1),
                            leadingColor: _primary,
                          ),
                          const SizedBox(height: 10),
                          _TimelineTile(
                            title: 'Refill: Metformin 500mg',
                            subtitle: 'Pharmacy ready for pickup',
                            leading: Icons.local_pharmacy_rounded,
                            leadingBg: _tileLeadBg(context, 2),
                            leadingColor: _success,
                          ),
                        ],
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
    ));
  }

  static List<Widget> _quickActionCards(BuildContext context) {
    final t = _actionTints(context);
    return [
      _QuickActionCard(
        icon: Icons.calendar_month_rounded,
        label: 'Appointments',
        subtitle: 'Book & view visits',
        tint: t[0],
        onTap: () => _comingSoon(context),
      ),
      _QuickActionCard(
        icon: Icons.folder_open_rounded,
        label: 'Health records',
        subtitle: 'Prescriptions & labs',
        tint: t[1],
        onTap: () => _comingSoon(context),
      ),
      _QuickActionCard(
        icon: Icons.psychology_rounded,
        label: 'AI health coach',
        subtitle: 'Guidance & triage',
        tint: t[2],
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
        subtitle: 'Doses & refills',
        tint: t[3],
        onTap: () => _comingSoon(context),
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

  static Color _tileLeadBg(BuildContext context, int index) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      const darkTints = [
        Color(0xFF2A1E20),
        Color(0xFF25203A),
        Color(0xFF1A261E),
      ];
      return darkTints[index % 3];
    }
    return const [Color(0xFFFFE5E5), Color(0xFFEDE7FF), Color(0xFFE3F2E6)][index % 3];
  }

  static void _comingSoon(BuildContext context) {
    final px = context.portalX;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This section will connect to your care workflow soon.'),
        backgroundColor: px.dock,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medicare AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Health Portal',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
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
              const SizedBox(width: 8),
              _circleIconButton(context, Icons.help_outline, () => _comingSoon(context)),
              const SizedBox(width: 8),
              _circleIconButton(context, Icons.receipt_long_rounded, () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppLogsScreen(),
                  ),
                );
              }),
              const SizedBox(width: 8),
              _circleIconButton(context, Icons.notifications_outlined, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('You have 2 new care reminders.'),
                    backgroundColor: context.portalX.dock,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
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
    final hour = DateTime.now().hour;
    final salute = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            salute,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your care dashboard',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor priorities, act fast in emergencies, and keep your health data organized in one place.',
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

  Widget _buildHeroCard(BuildContext context) {
    final px = context.portalX;
    final cs = context.medicareColorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [px.ctaStart, px.ctaEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Wellness index',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Stable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on your last check-in, vitals, and reported symptoms.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _heroStat('98%', 'Adherence', Colors.white),
                const SizedBox(width: 20),
                _heroStat('Low', 'Risk flags', Colors.white),
                const SizedBox(width: 20),
                _heroStat('2', 'Reminders', Colors.white),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _comingSoon(context),
                child: const Text(
                  'View care plan',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFFFF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF78C593),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF1D7F45), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient ID: ${patientId!}',
                    style: const TextStyle(
                      color: Color(0xFF1D7F45),
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
                  Tooltip(
                    message:
                        'Verifies the cloud token endpoint; does not start a call or notify anyone.',
                    child: OutlinedButton.icon(
                      onPressed: () => _testCallBackend(context),
                      icon: const Icon(Icons.health_and_safety_rounded),
                      label: const Text('Test LiveKit token (API only)'),
                    ),
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
        const SnackBar(content: Text('Only your assigned doctor can be called.')),
      );
      return;
    }
    final roomName = LiveKitCallService.buildRoomName(
      patientId: patientId!,
      doctorId: assignedDoctorId!,
    );
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doctorUid = CareAssignmentService.instance.doctorUidById(assignedDoctorId!) ?? '';
    if (myUid.isEmpty || doctorUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call mapping not ready yet. Please re-login.')),
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

  Future<void> _testCallBackend(BuildContext context) async {
    if (patientId == null || assignedDoctorId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please re-login and try again.')),
      );
      return;
    }
    final roomName = LiveKitCallService.buildRoomName(
      patientId: patientId!,
      doctorId: assignedDoctorId!,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking token service...')),
    );
    try {
      final creds = await LiveKitCallService.fetchJoinCredentials(
        roomName: roomName,
        identity: myUid,
        participantName: 'Patient ${patientId!}',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PASS: token issued for room $roomName\n'
            'Server: ${creds['serverUrl']}\n\n'
            'This only checks the API — it does not open WebSockets or notify '
            'anyone. If a real call shows "invalid API key", the LIVEKIT_* '
            'Function secrets are wrong or mixed from different projects.',
          ),
        ),
      );
    } catch (e) {
      AppLogService.instance.error('Patient token service test failed', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('FAIL: $e')),
      );
    }
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
      final updated = await CareAssignmentService.instance.reassignPatientToDoctor(
        patientUid: patientUid,
        patientId: patientId!,
        doctorId: chosen.id,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(
            patientId: patientId,
            assignedDoctor: updated.name,
            assignedDoctorId: updated.id,
          ),
        ),
      );
    } catch (e) {
      AppLogService.instance.error('Failed to change assigned doctor', e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change doctor: $e')),
      );
    }
  }

  Widget _heroStat(String value, String label, Color textColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.leadingBg,
    required this.leadingColor,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Color leadingBg;
  final Color leadingColor;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: leadingBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(leading, color: leadingColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurfaceVariant,
            size: 22,
          ),
        ],
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
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: cs.surfaceContainerHighest,
                        leading: CircleAvatar(
                          backgroundColor: doctor.avatarColor.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: doctor.avatarColor),
                        ),
                        title: Text(doctor.name),
                        subtitle: Text('${doctor.id} • ${doctor.specialization}'),
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

import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/dashboard_screen.dart';
import 'package:medicare_ai/screens/doctor_dashboard_screen.dart';
import 'package:medicare_ai/screens/signup_screen.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/firebase_auth_service.dart';
import 'package:medicare_ai/services/firebase_profile_service.dart';
import 'package:medicare_ai/services/push_notification_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/emergency_dock.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _openDashboardPatient() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, a, s) => const DashboardScreen(),
        transitionsBuilder: (context, animation, s, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _signIn() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final credential = await FirebaseAuthService.instance.signIn(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null || !mounted) return;
      await PushNotificationService.instance.syncTokenForCurrentUser();
      final profile = await FirebaseProfileService.instance.getProfile(uid);
      final role = (profile?['role'] as String?) ?? 'patient';
      final uniqueId = (profile?['uniqueId'] as String?) ?? '';
      if (role == 'doctor') {
        CareAssignmentService.instance.upsertDoctorProfile(
          doctorId: uniqueId,
          uid: uid,
          name: (profile?['name'] as String?) ?? '',
          specialization: (profile?['specialization'] as String?) ?? '',
        );
        CareAssignmentService.instance.setActiveDoctor(uniqueId);
        await CareAssignmentService.instance.hydrateDoctorPatients(uid);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DoctorDashboardScreen(
              doctorId: uniqueId,
              doctorName: profile?['name'] as String?,
            ),
          ),
        );
      } else {
        CareAssignmentService.instance.setActivePatient(uniqueId);
        await CareAssignmentService.instance.hydratePatientAssignment(uid);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DashboardScreen(
              patientId: uniqueId,
              assignedDoctor: profile?['assignedDoctorName'] as String?,
              assignedDoctorId: profile?['assignedDoctorId'] as String?,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    final px = context.portalX;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 40.0,
                  bottom: 120.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                    color: cs.shadow.withValues(alpha: 0.08),
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
                            TextButton(
                              onPressed: _openDashboardPatient,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const ThemeModeToggle(size: 0.95),
                            const SizedBox(width: 4),
                            _buildCircularIconButton(
                                context, Icons.help_outline),
                            const SizedBox(width: 10),
                            _buildCircularIconButton(
                                context, Icons.notifications_outlined),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to access your medical records and connect in an emergency.',
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildInputField(
                      context,
                      'Email Address',
                      Icons.email_outlined,
                      false,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      context,
                      'Password',
                      Icons.lock_outline,
                      true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _signIn,
                      child: Container(
                        width: double.infinity,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [px.ctaStart, px.ctaEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: px.subtleCardShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure Authentication',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'End-to-end encrypted login',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: px.verifiedBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF58B95E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    );
  }

  Widget _buildCircularIconButton(BuildContext context, IconData icon) {
    final cs = context.medicareColorScheme;
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: cs.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Icon(icon, color: cs.onSurface, size: 22),
    );
  }

  Widget _buildInputField(
    BuildContext context,
    String hint,
    IconData icon,
    bool isPassword, {
    TextEditingController? controller,
  }) {
    final cs = context.medicareColorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
            fontWeight: FontWeight.w500, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cs.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 24),
        ),
      ),
    );
  }
}

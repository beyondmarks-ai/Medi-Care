import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medicare_ai/screens/dashboard_screen.dart';
import 'package:medicare_ai/screens/doctor_dashboard_screen.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/document_storage_service.dart';
import 'package:medicare_ai/services/firebase_auth_service.dart';
import 'package:medicare_ai/services/firebase_profile_service.dart';
import 'package:medicare_ai/services/push_notification_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';
import 'package:medicare_ai/widgets/emergency_dock.dart';
import 'package:medicare_ai/widgets/theme_mode_toggle.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _doctorSpecializationController =
      TextEditingController();
  int _currentStep = 1;
  String? _uploadedFile;
  String? _uploadedDoctorId;
  UserRole _selectedRole = UserRole.patient;

  void _nextStep() {
    if (_currentStep < 3) {
      FocusScope.of(context).unfocus(); // Close keyboard
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus(); // Close keyboard
    if (_currentStep > 1) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context); // Go back to Login Screen
    }
  }

  Future<void> _finishSignUp() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and password are required.')),
        );
        return;
      }
      final credential = await FirebaseAuthService.instance.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      final uid = credential.user?.uid;
      if (uid == null) return;
      await PushNotificationService.instance.syncTokenForCurrentUser();

      if (_selectedRole == UserRole.doctor) {
        final doctor = await CareAssignmentService.instance.registerDoctorFromSignup(
          uid: uid,
          doctorName: _nameController.text,
          specialization: _doctorSpecializationController.text,
        );
        await FirebaseProfileService.instance.upsertUserProfile(
          uid: uid,
          role: 'doctor',
          uniqueId: doctor.id,
          name: doctor.name,
          email: email,
          phone: _phoneController.text.trim(),
          specialization: doctor.specialization,
        );
        if (!mounted) return;
        CareAssignmentService.instance.setActiveDoctor(doctor.id);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DoctorDashboardScreen(
              doctorId: doctor.id,
              doctorName: doctor.name,
            ),
          ),
        );
        return;
      }

      final patientId = CareAssignmentService.instance.generateUniquePatientId();
      final assignedDoctor = await CareAssignmentService.instance.assignDoctorToPatient(
        patientId: patientId,
        patientUid: uid,
        patientName: _nameController.text,
        patientPhone: _phoneController.text,
      );
      await FirebaseProfileService.instance.upsertUserProfile(
        uid: uid,
        role: 'patient',
        uniqueId: patientId,
        name:
            _nameController.text.trim().isEmpty ? 'Patient $patientId' : _nameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        assignedDoctorId: assignedDoctor.id,
        assignedDoctorName: assignedDoctor.name,
      );
      CareAssignmentService.instance.setActivePatient(patientId);
      await _showPatientWelcomePopup(
        patientId: patientId,
        doctorName: assignedDoctor.name,
        doctorId: assignedDoctor.id,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(
            patientId: patientId,
            assignedDoctor: assignedDoctor.name,
            assignedDoctorId: assignedDoctor.id,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'This email is already registered. Please sign in.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password is too weak (minimum 6 characters).',
        _ => e.message ?? 'Unable to sign up right now.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    }
  }

  Future<void> _showPatientWelcomePopup({
    required String patientId,
    required String doctorName,
    required String doctorId,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Account Created',
            style: TextStyle(
              color: Color(0xFF1D7F45),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your patient profile is active.',
                style: TextStyle(
                  color: Color(0xFF24553B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFFF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF78C593), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unique ID: $patientId',
                      style: const TextStyle(
                        color: Color(0xFF1D7F45),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assigned Doctor: $doctorName ($doctorId)',
                      style: const TextStyle(
                        color: Color(0xFF24553B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D7F45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadDocument({
    required String uploadType,
    required void Function(String name, String url) onUploaded,
  }) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final url = await DocumentStorageService.instance.uploadDocument(
        ownerUid: uid,
        role: _selectedRole == UserRole.doctor ? 'doctor' : 'patient',
        localPath: path,
        uploadType: uploadType,
      );
      final fileName = picked?.files.single.name ?? 'Uploaded document';
      onUploaded(fileName, url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _doctorSpecializationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
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
    );
  }

  Widget _buildStep1() {
    final cs = context.medicareColorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 1 of 3'),
          const SizedBox(height: 32),
          Text(
            'Create Account',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your health profile to securely manage your medical data and emergencies.',
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildInputField(
            'Full Name',
            Icons.person_outline,
            false,
            controller: _nameController,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Email Address',
            Icons.email_outlined,
            false,
            controller: _emailController,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Phone (For Emergencies)',
            Icons.phone_outlined,
            false,
            controller: _phoneController,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            'Secure Password',
            Icons.lock_outline,
            true,
            controller: _passwordController,
          ),
          const SizedBox(height: 20),
          _buildRoleSelector(),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _nextStep,
            child: _buildPrimaryButton('Continue to Contacts'),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account?",
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final cs = context.medicareColorScheme;
    final isDoctor = _selectedRole == UserRole.doctor;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 2 of 3'),
          const SizedBox(height: 32),
          Text(
            isDoctor ? 'Professional Details' : 'Emergency Contacts',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDoctor
                ? 'Share your hospital/clinic details and registration basics for profile verification.'
                : 'Please add at least 3 trusted emergency contacts. We will notify them instantly if you activate SOS.',
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          if (isDoctor) ...[
            _buildInputField('Medical Council Registration Number', Icons.badge_outlined, false),
            const SizedBox(height: 16),
            _buildInputField('Hospital/Clinic Name', Icons.local_hospital_outlined, false),
            const SizedBox(height: 16),
            _buildInputField(
              'Specialization',
              Icons.health_and_safety_outlined,
              false,
              controller: _doctorSpecializationController,
            ),
          ] else ...[
            _buildInputField('1st Contact Name & Phone', Icons.looks_one_outlined, false),
            const SizedBox(height: 16),
            _buildInputField('2nd Contact Name & Phone', Icons.looks_two_outlined, false),
            const SizedBox(height: 16),
            _buildInputField('3rd Contact Name & Phone', Icons.looks_3_outlined, false),
          ],
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _nextStep,
            child: _buildPrimaryButton(
              isDoctor ? 'Continue to Verification' : 'Continue to Medical Info',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final cs = context.medicareColorScheme;
    final isDoctor = _selectedRole == UserRole.doctor;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 3 of 3'),
          const SizedBox(height: 32),
          Text(
            isDoctor ? 'Doctor Verification' : 'Medical History',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDoctor
                ? 'Upload your doctor ID and a valid practice proof. This helps us verify professional accounts.'
                : 'Upload past prescriptions and briefly detail your chronic conditions. Our AI will securely organize this.',
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          if (isDoctor) ...[
            _buildInputField('Years of Experience', Icons.workspace_premium_outlined, false),
            const SizedBox(height: 16),
            _buildInputField('Issuing Authority (Council/Board)', Icons.account_balance_outlined, false),
            const SizedBox(height: 24),
            _buildDoctorIdUploadArea(),
          ] else ...[
            Text(
              'Past Medical History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiLineField(
              'Briefly describe any chronic conditions, allergies, or past surgeries...',
              Icons.medical_information_outlined,
            ),
            const SizedBox(height: 24),
            _buildUploadArea(),
          ],
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _finishSignUp,
            child: _buildPrimaryButton(
              isDoctor ? 'Submit for Doctor Verification' : 'Finish Sign Up & Verify',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    final cs = context.medicareColorScheme;
    final px = context.portalX;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am signing up as',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                role: UserRole.patient,
                title: 'Patient',
                subtitle: 'Personal health dashboard',
                icon: Icons.person_rounded,
                accent: px.ctaStart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleCard(
                role: UserRole.doctor,
                title: 'Doctor',
                subtitle: 'Clinical care dashboard',
                icon: Icons.medical_services_rounded,
                accent: px.ctaEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final cs = context.medicareColorScheme;
    final bool selected = _selectedRole == role;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : cs.outline.withValues(alpha: 0.3),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 20),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? accent : cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
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

  Widget _buildTopBar(String stepText) {
    final cs = context.medicareColorScheme;
    return Row(
      children: [
        GestureDetector(
          onTap: _prevStep,
          child: Container(
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
            child: Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Icon(Icons.arrow_back_ios, color: cs.onSurface, size: 18),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              stepText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.primary,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const ThemeModeIconButton(),
      ],
    );
  }

  Widget _buildPrimaryButton(String text) {
    final px = context.portalX;
    final cs = context.medicareColorScheme;
    return Container(
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
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
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
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
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

  Widget _buildMultiLineField(String hint, IconData icon) {
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
        maxLines: 4,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 16,
              top: 20,
              bottom: 20,
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cs.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    final cs = context.medicareColorScheme;
    final px = context.portalX;
    return GestureDetector(
      onTap: _showUploadOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _uploadedFile != null
              ? px.verifiedBackground
              : cs.primaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _uploadedFile != null
                ? const Color(0xFF58B95E).withValues(alpha: 0.4)
                : cs.primary.withValues(alpha: 0.35),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: _uploadedFile != null
            ? Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF58B95E).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF58B95E),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Record Uploaded Successfully',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _uploadedFile!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF58B95E),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _uploadedFile = null),
                    child: const Text(
                      'Change Document',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.cloud_upload_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to Upload Records',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PDF, JPG, PNG up to 10MB\nOur AI will securely analyze your medical data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showUploadOptions() {
    final cs = context.medicareColorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 5,
              width: 44,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Medical Document',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _buildUploadOption(
              Icons.document_scanner_outlined,
              'Scan Physical Paper',
              'Use your phone camera to scan physical prescriptions.',
              () {
                Navigator.pop(sheetContext);
                _pickAndUploadDocument(
                  uploadType: 'patient_record',
                  onUploaded: (name, url) {
                    if (!mounted) return;
                    setState(() {
                      _uploadedFile = name;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _buildUploadOption(
              Icons.folder_open_rounded,
              'Browse Digital Files',
              'Choose PDFs or image records from your phone storage.',
              () {
                Navigator.pop(sheetContext);
                _pickAndUploadDocument(
                  uploadType: 'patient_record',
                  onUploaded: (name, url) {
                    if (!mounted) return;
                    setState(() {
                      _uploadedFile = name;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorIdUploadArea() {
    final cs = context.medicareColorScheme;
    return GestureDetector(
      onTap: _showDoctorIdUploadOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _uploadedDoctorId != null
              ? const Color(0xFF58B95E).withValues(alpha: 0.12)
              : cs.primaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _uploadedDoctorId != null
                ? const Color(0xFF58B95E).withValues(alpha: 0.45)
                : cs.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _uploadedDoctorId != null
                  ? Icons.verified_rounded
                  : Icons.badge_rounded,
              color: _uploadedDoctorId != null ? const Color(0xFF58B95E) : cs.primary,
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              _uploadedDoctorId != null
                  ? 'Doctor ID uploaded'
                  : 'Upload Doctor ID / License',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _uploadedDoctorId ??
                  'Accepted: Medical council card, hospital ID, practice license (PDF/JPG/PNG)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _uploadedDoctorId != null ? const Color(0xFF58B95E) : cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (_uploadedDoctorId != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _uploadedDoctorId = null),
                child: const Text('Replace document'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showDoctorIdUploadOptions() {
    final cs = context.medicareColorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Upload doctor verification',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 18),
            _buildUploadOption(
              Icons.photo_camera_back_outlined,
              'Scan Doctor ID Card',
              'Capture your medical council/hospital ID',
              () {
                Navigator.pop(sheetContext);
                _pickAndUploadDocument(
                  uploadType: 'doctor_id',
                  onUploaded: (name, url) {
                    if (!mounted) return;
                    setState(() {
                      _uploadedDoctorId = name;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            _buildUploadOption(
              Icons.file_present_outlined,
              'Upload License PDF',
              'Attach registration certificate or license',
              () {
                Navigator.pop(sheetContext);
                _pickAndUploadDocument(
                  uploadType: 'doctor_id',
                  onUploaded: (name, url) {
                    if (!mounted) return;
                    setState(() {
                      _uploadedDoctorId = name;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final cs = context.medicareColorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: cs.onSurfaceVariant,
              size: 16,
            )
          ],
        ),
      ),
    );
  }
}

enum UserRole { patient, doctor }

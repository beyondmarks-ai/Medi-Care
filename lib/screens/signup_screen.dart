import 'package:flutter/material.dart';
import 'package:medicare_ai/services/emergency_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 1;
  String? _uploadedFile;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Light grey background
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
            
            // Bottom floating dock
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: _buildBottomDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 1 of 3'),
          const SizedBox(height: 32),
          
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up your health profile to securely manage your medical data and emergencies.',
            style: TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.4),
          ),
          const SizedBox(height: 32),

          _buildInputField('Full Name', Icons.person_outline, false),
          const SizedBox(height: 16),
          _buildInputField('Email Address', Icons.email_outlined, false),
          const SizedBox(height: 16),
          _buildInputField('Phone (For Emergencies)', Icons.phone_outlined, false),
          const SizedBox(height: 16),
          _buildInputField('Secure Password', Icons.lock_outline, true),
          
          const SizedBox(height: 32),

          GestureDetector(onTap: _nextStep, child: _buildPrimaryButton('Continue to Contacts')),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account?", style: TextStyle(color: Color(0xFF757575), fontSize: 15)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sign In', style: TextStyle(color: Color(0xFF916CF2), fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 2 of 3'),
          const SizedBox(height: 32),
          
          const Text(
            'Emergency Contacts',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please add at least 3 trusted emergency contacts. We will notify them instantly if you activate SOS.',
            style: TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.4),
          ),
          const SizedBox(height: 32),

          _buildInputField('1st Contact Name & Phone', Icons.looks_one_outlined, false),
          const SizedBox(height: 16),
          _buildInputField('2nd Contact Name & Phone', Icons.looks_two_outlined, false),
          const SizedBox(height: 16),
          _buildInputField('3rd Contact Name & Phone', Icons.looks_3_outlined, false),
          
          const SizedBox(height: 32),

          GestureDetector(onTap: _nextStep, child: _buildPrimaryButton('Continue to Medical Info')),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar('Step 3 of 3'),
          const SizedBox(height: 32),
          
          const Text(
            'Medical History',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload past prescriptions and briefly detail your chronic conditions. Our AI will securely organize this.',
            style: TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.4),
          ),
          const SizedBox(height: 32),

          const Text(
            'Past Medical History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 12),
          _buildMultiLineField('Briefly describe any chronic conditions, allergies, or past surgeries...', Icons.medical_information_outlined),
          const SizedBox(height: 24),
          
          _buildUploadArea(),
          
          const SizedBox(height: 40),

          GestureDetector(onTap: () {}, child: _buildPrimaryButton('Finish Sign Up & Verify')),
          
        ],
      ),
    );
  }

  Widget _buildTopBar(String stepText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _prevStep,
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.only(left: 6.0),
              child: Icon(Icons.arrow_back_ios, color: Color(0xFF1E1E1E), size: 18),
            ),
          ),
        ),
        Text(
          stepText,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF916CF2), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC7A7FF), Color(0xFF916CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF916CF2).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF2B1B4A),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2B1B4A).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showSOSModal(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8B8B), Color(0xFFFF4949)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF4949).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: const Row(
                  children: [
                    Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('SOS Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _buildDarkDockIcon(Icons.call_rounded, () {
                  _showEmergencyContactsModal(context);
                }),
                const SizedBox(width: 8),
                _buildDarkDockIcon(Icons.location_on_rounded, () {
                  EmergencyService.sendLiveLocation(context);
                }),
                const SizedBox(width: 8),
                _buildDarkDockIcon(Icons.support_agent_rounded, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening 24/7 Medical Support Chat...'), backgroundColor: Color(0xFF2B1B4A)),
                  );
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDarkDockIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.transparent,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 26),
      ),
    );
  }

  Widget _buildInputField(String hint, IconData icon, bool isPassword) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 6))
        ],
      ),
      child: TextField(
        obscureText: isPassword,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: Icon(icon, color: const Color(0xFF916CF2), size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 24),
        ),
      ),
    );
  }

  Widget _buildMultiLineField(String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 6))
        ],
      ),
      child: TextField(
        maxLines: 4, // More space
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16, top: 20, bottom: 20),
            child: Icon(icon, color: const Color(0xFF916CF2), size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _showUploadOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _uploadedFile != null ? const Color(0xFFF2F8EE) : const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _uploadedFile != null ? const Color(0xFF58B95E).withValues(alpha: 0.4) : const Color(0xFF916CF2).withValues(alpha: 0.3), 
            width: 1.5, 
            style: BorderStyle.solid
          ),
        ),
        child: _uploadedFile != null 
          ? Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF58B95E).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF58B95E), size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Record Uploaded Successfully',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  _uploadedFile!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF58B95E), fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _uploadedFile = null),
                  child: const Text('Change Document', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                )
              ],
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF916CF2).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF916CF2), size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap to Upload Records',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PDF, JPG, PNG up to 10MB\nOur AI will securely analyze your medical data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF757575), fontSize: 13, height: 1.4),
                ),
              ],
            ),
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Floating rounded sheet style
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
          ]
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(height: 5, width: 44, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Text('Add Medical Document', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
            const SizedBox(height: 24),
            
            _buildUploadOption(Icons.document_scanner_outlined, 'Scan Physical Paper', 'Use your phone camera to scan physical prescriptions.', () {
               Navigator.pop(context);
               setState(() => _uploadedFile = 'Scanned_Prescription_Doc.pdf');
            }),
            const SizedBox(height: 16),
            _buildUploadOption(Icons.folder_open_rounded, 'Browse Digital Files', 'Choose PDFs or image records from your phone storage.', () {
               Navigator.pop(context);
               setState(() => _uploadedFile = 'Past_Medical_Records.pdf');
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF916CF2), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16)
          ],
        ),
      ),
    );
  }

  void _showEmergencyContactsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 10)]
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(height: 5, width: 44, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Text('Call Emergency Contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
            const SizedBox(height: 8),
            const Text('Select a trusted contact from your network to ring immediately.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            
            _buildContactOptionCard(context, 'Mother', '+91 98765 43210'),
            const SizedBox(height: 12),
            _buildContactOptionCard(context, 'Husband', '+91 87654 32109'),
            const SizedBox(height: 12),
            _buildContactOptionCard(context, 'Brother', '+91 76543 21098'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOptionCard(BuildContext context, String relation, String phone) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        // Call the real dialer
        EmergencyService.dialNumber(context, phone);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.person, color: Color(0xFF916CF2), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(relation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF58B95E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call, color: Color(0xFF58B95E), size: 20)
            )
          ],
        ),
      ),
    );
  }

  void _showSOSModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: const Color(0xFFFF4949).withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10)]
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFFFECEC), shape: BoxShape.circle),
              child: const Icon(Icons.emergency_outlined, color: Color(0xFFFF4949), size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Ambulance SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
            const SizedBox(height: 8),
            const Text(
              'You are about to contact the nearest ambulance dispatch and hospital emergency unit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                // Directly call the primary medical emergency number in India
                EmergencyService.dialNumber(context, '108');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF8B8B), Color(0xFFFF4949)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF4949).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6))]
                ),
                child: const Center(
                  child: Text('Dial Ambulance Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel Alarm', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 15)),
            )
          ],
        ),
      ),
    );
  }
}

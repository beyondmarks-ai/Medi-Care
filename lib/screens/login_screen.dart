import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/signup_screen.dart';
import 'package:medicare_ai/services/emergency_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Light grey background inspired by image
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0, bottom: 120.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar (Avatar + Icons like in image)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              padding: const EdgeInsets.all(4), // Little padding for the logo
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white, // Changed background to white to pop
                                boxShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 10)]
                              ),
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Medicare AI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                                Text(
                                  'Health Portal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Circular buttons like the image's search & bell
                        Row(
                          children: [
                            _buildCircularIconButton(Icons.help_outline),
                            const SizedBox(width: 12),
                            _buildCircularIconButton(Icons.notifications_outlined),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 40),
                    
                    // Welcome Title
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to access your medical records and connect in an emergency.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF757575),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Inputs matching the Actions container style
                    _buildInputField('Email Address', Icons.email_outlined, false),
                    const SizedBox(height: 20),
                    _buildInputField('Password', Icons.lock_outline, true),
                    
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF916CF2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Beautiful login button inspired by the big purple card
                    GestureDetector(
                      onTap: () {},
                      child: Container(
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
                            BoxShadow(
                              color: const Color(0xFF916CF2).withValues(alpha: 0.3),
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
                    
                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF916CF2),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    
                    // Profile Setup / Status inspired section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure Authentication',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'End-to-end encrypted login',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F8EE), // faint green
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF58B95E)),
                          ),
                        ],
                      ),
                    ),
                    
                  ],
                ),
              ),
            ),
            
            // Bottom floating dock (from the image) 
            // Gives the "professional and emergency" vibe
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B1B4A), // Very dark purple
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2B1B4A).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Emergency SOS Action (Like the + Create button in image)
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
                              BoxShadow(
                                color: const Color(0xFFFF4949).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'SOS Connect',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Secondary bottom actions like in the image
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIconButton(IconData icon) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Icon(icon, color: const Color(0xFF1E1E1E), size: 22),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 24),
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

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicare_ai/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    _playVideoIntro();
  }

  Future<void> _playVideoIntro() async {
    // 5-minute timeout logic for emergencies
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayedMs = prefs.getInt('last_intro_playback') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      
      // If less than 5 minutes have passed since last intro, skip directly to app
      if (nowMs - lastPlayedMs < const Duration(minutes: 5).inMilliseconds) {
         _navigateToLogin();
         return;
      }
      
      // Store the current timestamp as the new playback milestone
      await prefs.setInt('last_intro_playback', nowMs);
    } catch (_) { 
      // If preferences fail, proceed to load the video as a fallback
    }

    _controller = VideoPlayerController.asset('assets/intro.mp4');
    
    try {
      await _controller.initialize();
      
      setState(() {
        _isVideoReady = true;
      });
      await _controller.play();

      // Listen for when video finishes 
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration && _controller.value.duration.inMilliseconds > 0) {
          _navigateToLogin();
        }
      });

      // Failsafe: if video is extremely long, transition after 4 seconds of playback
      Future.delayed(const Duration(seconds: 5), () {
        _navigateToLogin();
      });

    } catch (e) {
      // If video fails to load, immediately jump to login
      _navigateToLogin(); 
    }
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    
    // Smooth fade transition into the main app
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background as requested
      body: Center(
        child: _isVideoReady
            ? SizedBox(
                width: 250, // Make the video smaller like a central animated logo
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.85, // Accurately slices off the bottom 15% (footer/watermark)
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              )
            : const CircularProgressIndicator(color: Color(0xFF916CF2)),
      ),
    );
  }
}

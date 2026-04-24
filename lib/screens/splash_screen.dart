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
  VideoPlayerController? _controller;
  bool _navigated = false;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    _playVideoIntro();
  }

  Future<void> _playVideoIntro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayedMs = prefs.getInt('last_intro_playback') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (nowMs - lastPlayedMs < const Duration(minutes: 5).inMilliseconds) {
        _navigateToLogin();
        return;
      }

      await prefs.setInt('last_intro_playback', nowMs);
    } catch (_) {}

    _controller = VideoPlayerController.asset('assets/intro.mp4');

    try {
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {
        _isVideoReady = true;
      });
      await _controller!.play();

      _controller!.addListener(_onVideoTick);

      Future.delayed(const Duration(seconds: 5), _navigateToLogin);
    } catch (e) {
      await _controller?.dispose();
      _controller = null;
      _navigateToLogin();
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    if (d.inMilliseconds > 0 && c.value.position >= d) {
      c.removeListener(_onVideoTick);
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _controller?.removeListener(_onVideoTick);
    _controller?.pause();

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
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isVideoReady && _controller != null
            ? SizedBox(
                width: 250,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.85,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              )
            : CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'login_screen.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isReady = false;
  bool _navigating = false;

  static const _animationPath = 'assets/lottie/splash_screen1.json';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  Future<void> _navigateToLogin() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
      body: Center(
        child: AnimatedOpacity(
          opacity: _isReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Lottie.asset(
            _animationPath,
            controller: _controller,
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward();
              setState(() => _isReady = true);
              Future.delayed(
                composition.duration + const Duration(seconds: 1),
                _navigateToLogin,
              );
            },
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

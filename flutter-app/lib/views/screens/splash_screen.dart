import 'package:flutter/material.dart';

import '../../controllers/splash_controller.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/splash/splash_animation_section.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashController _controller = const SplashController();

  @override
  void initState() {
    super.initState();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    await _controller.start(
      onCompleted: () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _controller.content;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kSplashBackgroundTop, kSplashBackgroundBottom],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              right: -50,
              child: _SplashGlow(size: 220, color: Color(0x3364D3C6)),
            ),
            const Positioned(
              bottom: -100,
              left: -60,
              child: _SplashGlow(size: 260, color: Color(0x224C6FFF)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final animationSize = (constraints.maxWidth * 0.62).clamp(
                    240.0,
                    380.0,
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: SplashAnimationSection(
                            animationAsset: content.animationAsset,
                            size: animationSize,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

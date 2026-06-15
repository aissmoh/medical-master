import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashAnimationSection extends StatelessWidget {
  const SplashAnimationSection({
    super.key,
    required this.animationAsset,
    required this.size,
  });

  final String animationAsset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFE3EEF9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F4C81),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x0F6CD6FF),
            blurRadius: 48,
            spreadRadius: 6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Lottie.asset(
        animationAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}

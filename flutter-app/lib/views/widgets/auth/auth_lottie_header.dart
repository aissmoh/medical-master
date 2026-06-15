import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AuthLottieHeader extends StatelessWidget {
  const AuthLottieHeader({
    super.key,
    this.animation = 'assets/lottie/splash_screen1.json',
    this.height = 140,
  });

  final String animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Lottie.asset(
        animation,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

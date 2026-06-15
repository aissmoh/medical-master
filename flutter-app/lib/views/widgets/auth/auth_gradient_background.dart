import 'package:flutter/material.dart';

class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F7)],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

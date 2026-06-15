import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/splash_content.dart';

class SplashTextSection extends StatelessWidget {
  const SplashTextSection({super.key, required this.content});

  final SplashContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          content.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content.subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: kAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          content.description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

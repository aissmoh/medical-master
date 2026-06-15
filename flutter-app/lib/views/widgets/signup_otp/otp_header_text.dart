import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class OtpHeaderText extends StatelessWidget {
  const OtpHeaderText({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kTextSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

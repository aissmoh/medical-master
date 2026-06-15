import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'otp_header_text.dart';
import 'otp_primary_button.dart';

class OtpResultView extends StatelessWidget {
  const OtpResultView({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final bool isSuccess;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      child: Column(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            size: 80,
          ),
          const SizedBox(height: 20),
          OtpHeaderText(title: title, subtitle: subtitle),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kInputBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kInputBorder),
            ),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          OtpPrimaryButton(label: buttonLabel, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

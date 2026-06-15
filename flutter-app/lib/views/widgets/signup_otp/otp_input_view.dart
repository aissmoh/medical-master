import 'package:flutter/material.dart';

import '../../../controllers/signup_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'otp_code_input.dart';
import 'otp_header_text.dart';
import 'otp_primary_button.dart';

class OtpInputView extends StatelessWidget {
  const OtpInputView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onVerify,
    required this.onResend,
  });

  final SignupController controller;
  final FocusNode focusNode;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      child: Column(
        children: [
          const OtpHeaderText(
            title: 'Vérification OTP',
            subtitle: 'Entrez le code à 4 chiffres envoyé à votre adresse e-mail.',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kInputBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kInputBorder),
            ),
            child: Text(
              controller.maskedPendingEmail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kAccent2, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if ((controller.state.otpFeedbackMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              controller.state.otpFeedbackMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 28),
          OtpCodeInput(
            controller: controller.otpController,
            focusNode: focusNode,
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: controller.state.isResendingOtp ? null : onResend,
            child: Text(
              controller.state.isResendingOtp ? 'Renvoi en cours...' : 'Renvoyer le code',
              style: TextStyle(
                color: controller.state.isResendingOtp ? kTextSecondary : kAccent2,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OtpPrimaryButton(
            label: controller.state.isVerifyingOtp ? 'Vérification...' : 'Vérifier',
            onPressed: onVerify,
          ),
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
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
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

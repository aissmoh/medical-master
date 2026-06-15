import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../models/otp_verification_stage.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/auth/auth_gradient_background.dart';
import '../widgets/auth/auth_lottie_header.dart';
import '../widgets/login/login_back_button.dart';
import '../widgets/signup_otp/otp_input_view.dart';
import '../widgets/signup_otp/otp_result_view.dart';
import 'login_screen.dart';

class SignupOtpScreen extends StatefulWidget {
  const SignupOtpScreen({super.key, required this.controller});

  final SignupController controller;

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  late final FocusNode _otpFocusNode;

  SignupController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _otpFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.verifyOtp();
    if (!mounted || result.success) return;
    AppToast.show(context, message: result.message, type: AppToastType.error);
  }

  Future<void> _handleResend() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.resendOtp();
    if (!mounted) return;
    AppToast.show(context, message: result.message, type: AppToastType.success);
  }

  void _handleDone() {
    _controller.completeOtpFlow();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _handleRetry() {
    _controller.resetOtpFlow();
    FocusScope.of(context).requestFocus(_otpFocusNode);
  }

  Widget _buildBody() {
    switch (_controller.state.otpStage) {
      case OtpVerificationStage.success:
        return OtpResultView(
          isSuccess: true,
          title: 'Vérifié',
          subtitle: _controller.state.otpFeedbackMessage ?? 'Votre compte a été vérifié avec succès.',
          buttonLabel: 'Terminé',
          onPressed: _handleDone,
        );
      case OtpVerificationStage.failure:
        return OtpResultView(
          isSuccess: false,
          title: 'Échec',
          subtitle: _controller.state.otpFeedbackMessage ?? 'Code OTP invalide ou expiré.',
          buttonLabel: 'Réessayer',
          onPressed: _handleRetry,
        );
      case OtpVerificationStage.input:
        return OtpInputView(
          controller: _controller,
          focusNode: _otpFocusNode,
          onVerify: _handleVerify,
          onResend: _handleResend,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LoginBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AuthLottieHeader(height: 120),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../controllers/login_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_storage_service.dart';
import 'companion_dashboard_screen.dart';
import 'patient_dashboard_screen.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/custom_button.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/auth/auth_gradient_background.dart';
import '../widgets/auth/auth_lottie_header.dart';
import '../widgets/login/login_back_button.dart';
import '../widgets/login/login_options_row.dart';
import '../widgets/login/login_signup_prompt.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message, {required AppToastType type, String? title}) {
    AppToast.show(context, message: message, type: type, title: title);
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.submitLogin();
    if (!mounted) return;

    _showMessage(result.message, type: result.success ? AppToastType.success : AppToastType.error);
    if (!result.success) return;

    final userData = result.data['user'];
    final isPatient = userData?['isPatient'] ?? true;
    final userName = userData?['name'] ?? '';

    if (userName.isNotEmpty) {
      await const AuthStorageService().saveName(userName);
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isPatient ? const PatientDashboardScreen() : const CompanionDashboardScreen(),
      ),
      (route) => false,
    );
  }

  void _openSignUp() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _openForgotPassword() {
    _showMessage('La récupération du mot de passe sera bientôt disponible.', type: AppToastType.info);
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
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LoginBackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const AuthLottieHeader(height: 140),
                      _AuthCard(
                        child: Column(
                          children: [
                            const Text(
                              'Connexion',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Accédez à votre espace médical',
                              style: TextStyle(fontSize: 14, color: kTextSecondary),
                            ),
                            const SizedBox(height: 28),
                            CustomTextField(
                              hintText: 'Adresse e-mail',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              controller: _controller.emailController,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              hintText: 'Mot de passe',
                              prefixIcon: Icons.lock_outline,
                              controller: _controller.passwordController,
                              obscureText: _controller.state.obscurePassword,
                              suffixIcon: IconButton(
                                onPressed: _controller.togglePasswordVisibility,
                                icon: Icon(
                                  _controller.state.obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: kTextSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            LoginOptionsRow(
                              rememberMe: _controller.state.rememberMe,
                              onRememberChanged: _controller.toggleRememberMe,
                              onForgotPassword: _openForgotPassword,
                            ),
                            const SizedBox(height: 20),
                            CustomButton(
                              label: _controller.state.isSubmitting
                                  ? 'Connexion...'
                                  : 'Se connecter',
                              onPressed: _submitLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      LoginSignupPrompt(onSignUp: _openSignUp),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
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

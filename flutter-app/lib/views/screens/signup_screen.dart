import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/custom_button.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/auth/auth_gradient_background.dart';
import '../widgets/auth/auth_lottie_header.dart';
import '../widgets/login/login_back_button.dart';
import '../widgets/role/role_option_card.dart';
import '../widgets/signup/signup_signin_prompt.dart';
import 'login_screen.dart';
import 'signup_otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final SignupController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignupController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message, {required AppToastType type, String? title}) {
    AppToast.show(context, message: message, type: type, title: title);
  }

  Future<void> _submitSignup() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.submitSignup();
    if (!mounted) return;

    _showMessage(result.message, type: result.success ? AppToastType.success : AppToastType.error);
    if (!result.success) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignupOtpScreen(controller: _controller)),
    );
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                      const AuthLottieHeader(height: 120),
                      _AuthCard(
                        child: Column(
                          children: [
                            const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Rejoignez votre espace médical',
                              style: TextStyle(fontSize: 13, color: kTextSecondary),
                            ),
                            const SizedBox(height: 24),
                            CustomTextField(
                              hintText: 'Nom complet',
                              prefixIcon: Icons.person_outline,
                              controller: _controller.nameController,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              hintText: 'Adresse e-mail',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              controller: _controller.emailController,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              hintText: 'Numéro de téléphone',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              controller: _controller.phoneController,
                            ),
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            CustomTextField(
                              hintText: 'Confirmer le mot de passe',
                              prefixIcon: Icons.lock_outline,
                              controller: _controller.confirmPasswordController,
                              obscureText: _controller.state.obscureConfirmPassword,
                              suffixIcon: IconButton(
                                onPressed: _controller.toggleConfirmPasswordVisibility,
                                icon: Icon(
                                  _controller.state.obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: kTextSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Choisissez votre rôle',
                                style: TextStyle(color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: RoleOptionCard(
                                    role: UserRole.patient,
                                    isSelected: _controller.state.selectedRole == UserRole.patient,
                                    onTap: () => _controller.selectRole(UserRole.patient),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RoleOptionCard(
                                    role: UserRole.gardeMalade,
                                    isSelected: _controller.state.selectedRole == UserRole.gardeMalade,
                                    onTap: () => _controller.selectRole(UserRole.gardeMalade),
                                  ),
                                ),
                              ],
                            ),
                            if (_controller.state.selectedRole == UserRole.patient) ...[
                              const SizedBox(height: 18),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Groupe sanguin',
                                  style: TextStyle(color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: kInputBackground,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: kInputBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _controller.state.selectedGroupeSanguin,
                                    hint: const Text('Sélectionnez votre groupe sanguin', style: TextStyle(color: kTextSecondary)),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: kTextSecondary),
                                    items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                        .map((value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ))
                                        .toList(),
                                    onChanged: (newValue) {
                                      if (newValue != null) _controller.selectGroupeSanguin(newValue);
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            CustomButton(
                              label: _controller.state.isSubmitting
                                  ? 'Création en cours...'
                                  : 'Créer un compte',
                              onPressed: _submitSignup,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SignupSigninPrompt(onSignIn: _openLogin),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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

import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/input_decoration_factory.dart';
import '../../models/user_role.dart';
import '../widgets/backgrounds/login_background.dart';
import '../widgets/common/delayed_fade_slide.dart';
import '../widgets/common/glass_panel.dart';
import '../widgets/common/glow_button.dart';
import 'patient_dashboard_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final controller = AuthController(role);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Accès ${controller.roleLabel}'),
      ),
      body: Stack(
        children: [
          const LoginBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 120),
                    child: Text(
                      'Renseignez vos informations pour continuer.',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    child: GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            TextField(
                              decoration: buildInputDecoration(
                                'Nom',
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              decoration: buildInputDecoration(
                                'Email',
                                icon: Icons.email,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              decoration: buildInputDecoration(
                                'Mot de passe',
                                icon: Icons.lock,
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 20),
                            GlowButton(
                              label: 'Créer un compte',
                              colors: const [kAccent, kAccent2],
                              onPressed: () {
                                if (controller.canOpenPatientDashboard) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PatientDashboardScreen(),
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Se connecter'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

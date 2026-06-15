import 'package:flutter/material.dart';

import '../../controllers/role_selection_controller.dart';
import '../../models/user_role.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/custom_button.dart';
import '../widgets/login/login_back_button.dart';
import '../widgets/role/role_option_card.dart';
import '../widgets/role/role_selection_header.dart';
import 'patient_dashboard_screen.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  late final RoleSelectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoleSelectionController();
  }

  void _showMessage(String message, {required AppToastType type}) {
    AppToast.show(context, message: message, type: type);
  }

  void _continue() {
    if (!_controller.canContinue) {
      _showMessage(
        'Veuillez sélectionner un rôle pour continuer.',
        type: AppToastType.warning,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PatientDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 420
                    ? 20.0
                    : 28.0;
                final imageHeight = (constraints.maxHeight * 0.32).clamp(
                  180.0,
                  320.0,
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: LoginBackButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Image.asset(
                              'assets/images/role.png',
                              height: imageHeight,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 20),
                            const RoleSelectionHeader(),
                            const SizedBox(height: 34),
                            Row(
                              children: [
                                RoleOptionCard(
                                  role: UserRole.patient,
                                  isSelected:
                                      _controller.selectedRole ==
                                      UserRole.patient,
                                  onTap: () =>
                                      _controller.selectRole(UserRole.patient),
                                ),
                                const SizedBox(width: 16),
                                RoleOptionCard(
                                  role: UserRole.gardeMalade,
                                  isSelected:
                                      _controller.selectedRole ==
                                      UserRole.gardeMalade,
                                  onTap: () => _controller.selectRole(
                                    UserRole.gardeMalade,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 42),
                            CustomButton(
                              label: 'Terminer l’inscription',
                              onPressed: _continue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

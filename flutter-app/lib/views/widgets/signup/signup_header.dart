import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SignupHeader extends StatelessWidget {
  const SignupHeader({
    super.key,
    this.title = 'Créer un compte',
    this.subtitle =
        'Créez un nouveau compte pour commencer et profiter d’un accès simple à nos fonctionnalités.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: kTextSecondary, height: 1.6),
        ),
      ],
    );
  }
}

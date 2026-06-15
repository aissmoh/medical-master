import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RoleSelectionHeader extends StatelessWidget {
  const RoleSelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Choisissez votre rôle',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sélectionnez Patient si vous souhaitez suivre votre état de santé ou Garde malade pour accompagner un proche.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: kTextSecondary, height: 1.6),
        ),
      ],
    );
  }
}

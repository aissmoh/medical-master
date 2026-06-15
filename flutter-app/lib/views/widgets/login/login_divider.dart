import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class LoginDivider extends StatelessWidget {
  const LoginDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: kDivider, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Ou continuer plus tard',
            style: TextStyle(color: kTextSecondary, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: kDivider, thickness: 1)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class LoginSignupPrompt extends StatelessWidget {
  const LoginSignupPrompt({super.key, required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          "Vous n'avez pas de compte ? ",
          style: TextStyle(color: kTextSecondary, fontSize: 15),
        ),
        GestureDetector(
          onTap: onSignUp,
          child: const Text(
            'Inscrivez-vous ici',
            style: TextStyle(
              color: kAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

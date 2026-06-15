import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SignupSigninPrompt extends StatelessWidget {
  const SignupSigninPrompt({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Vous avez déjà un compte ? ',
          style: TextStyle(color: kTextSecondary, fontSize: 15),
        ),
        GestureDetector(
          onTap: onSignIn,
          child: const Text(
            'Connectez-vous',
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

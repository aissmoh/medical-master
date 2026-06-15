import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class LoginOptionsRow extends StatelessWidget {
  const LoginOptionsRow({
    super.key,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final VoidCallback onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: onRememberChanged,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: rememberMe,
                  activeColor: kAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(color: kInputBorder),
                  onChanged: (_) => onRememberChanged(),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Se souvenir de moi',
                style: TextStyle(color: kTextPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          child: const Text(
            'Mot de passe oublié ?',
            style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

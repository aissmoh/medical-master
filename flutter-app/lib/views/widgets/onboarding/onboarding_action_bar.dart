import 'package:flutter/material.dart';

class OnboardingActionBar extends StatelessWidget {
  const OnboardingActionBar({
    super.key,
    required this.isLastPage,
    required this.onSkip,
    required this.onNext,
    required this.onFinish,
  });

  final bool isLastPage;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: isLastPage ? null : onSkip,
          child: Text(
            'Passer',
            style: TextStyle(
              color: isLastPage
                  ? const Color(0xFFB7BBD3)
                  : const Color(0xFF7A80A8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: isLastPage ? onFinish : onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A63FF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(isLastPage ? 'Commencer' : 'Suivant'),
        ),
      ],
    );
  }
}

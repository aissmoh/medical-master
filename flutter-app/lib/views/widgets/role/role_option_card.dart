import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';

class RoleOptionCard extends StatelessWidget {
  const RoleOptionCard({
    super.key,
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _backgroundColor {
    return role == UserRole.patient
        ? const Color(0xFFD7F4F7)
        : const Color(0xFFFEE4C6);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isSelected ? kAccent2 : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  role == UserRole.patient
                      ? Icons.favorite_outline
                      : Icons.health_and_safety_outlined,
                  color: kTextPrimary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                role == UserRole.patient ? 'Patient' : 'Garde malade',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

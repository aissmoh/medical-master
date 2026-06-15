import 'package:flutter/material.dart';

import '../../../core/utils/color_utils.dart';

class VitalCard extends StatelessWidget {
  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    required this.status,
    required this.referenceRange,
    required this.observation,
    required this.updatedAt,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final String status;
  final String referenceRange;
  final String observation;
  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: withOpacity(const Color(0xFF0F172A), 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: colors),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: withOpacity(colors.last, 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updatedAt,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: withOpacity(colors.last, 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: withOpacity(colors.last, 0.22),
                    ),
                  ),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF1F2937),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              referenceRange,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475467),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              observation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF111827),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

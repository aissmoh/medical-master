import 'package:flutter/material.dart';

class NurseInfoCard extends StatelessWidget {
  final Map<String, dynamic>? nurseInfo;
  final bool isLoading;
  final VoidCallback? onContact;
  final VoidCallback? onAlert;

  const NurseInfoCard({
    super.key,
    this.nurseInfo,
    this.isLoading = false,
    this.onContact,
    this.onAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF14B8A6).withValues(alpha: 0.08), const Color(0xFF0D9488).withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF14B8A6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mon garde malade',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    _buildNurseName(),
                  ],
                ),
              ),
              if (!isLoading && nurseInfo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ASSIGNÉ',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0D9488), letterSpacing: 0.8),
                  ),
                ),
            ],
          ),
          if (nurseInfo != null && !isLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onContact != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_rounded,
                      label: 'Contacter',
                      color: const Color(0xFF3B82F6),
                      onTap: onContact!,
                    ),
                  ),
                if (onContact != null && onAlert != null) const SizedBox(width: 10),
                if (onAlert != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.warning_amber_rounded,
                      label: 'Alerter',
                      color: const Color(0xFFEF4444),
                      onTap: onAlert!,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNurseName() {
    if (isLoading) {
      return Row(
        children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF14B8A6))),
          const SizedBox(width: 6),
          Text('Recherche...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      );
    }
    if (nurseInfo == null) {
      return Text('Aucun garde assigné', style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500));
    }
    return Text(
      'Dr. ${nurseInfo!['name'] ?? 'Garde malade'}',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

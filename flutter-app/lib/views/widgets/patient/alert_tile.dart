import 'package:flutter/material.dart';

class AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback? onCancel;

  const AlertTile({super.key, required this.alert, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final type = (alert['type'] as String?) ?? 'emergency';
    final status = (alert['status'] as String?) ?? 'active';
    final message = (alert['message'] as String?) ?? 'Alerte';
    final createdAt = alert['createdAt'] != null ? DateTime.parse(alert['createdAt']) : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(type),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        const SizedBox(width: 8),
                        Text(_timeAgo(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
              if (status == 'active' && onCancel != null)
                Material(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, size: 18, color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
          if (alert['location'] != null && alert['location']['coordinates'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'GPS: ${(alert['location']['coordinates'] as List).reversed.join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
          if (alert['acknowledgedBy'] != null && alert['acknowledgedBy']['name'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
                const SizedBox(width: 4),
                Text(
                  'Pris en charge par ${alert['acknowledgedBy']['name']}',
                  style: TextStyle(fontSize: 11, color: Colors.green[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(String type) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _typeColor(type).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_typeIcon(type), size: 22, color: _typeColor(type)),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'direct_alert': return const Color(0xFF14B8A6);
      case 'fall': return const Color(0xFFF97316);
      case 'vitals_critical': return const Color(0xFFEF4444);
      default: return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'direct_alert': return Icons.local_hospital_rounded;
      case 'fall': return Icons.person_off;
      case 'vitals_critical': return Icons.favorite;
      default: return Icons.warning_amber_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFFEF4444);
      case 'acknowledged': return const Color(0xFFF59E0B);
      case 'resolved': return const Color(0xFF10B981);
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'direct_alert': return 'Alerte garde malade';
      case 'fall': return 'Chute';
      case 'vitals_critical': return 'Constantes critiques';
      case 'emergency': return 'Urgence SOS';
      default: return 'Alerte';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Active', const Color(0xFFEF4444)),
      'acknowledged' => ('Prise en charge', const Color(0xFFF59E0B)),
      'resolved' => ('Résolue', const Color(0xFF10B981)),
      'cancelled' => ('Annulée', Colors.grey),
      _ => ('Inconnu', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

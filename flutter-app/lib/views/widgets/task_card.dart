import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String patientName;
  final String time;
  final String type;
  final bool isCompleted;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;

  const TaskCard({
    Key? key,
    required this.title,
    required this.patientName,
    required this.time,
    required this.type,
    this.isCompleted = false,
    this.onComplete,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? Colors.grey[300]! : _getTypeColor(type).withOpacity(0.3),
          ),
          boxShadow: [
            if (!isCompleted)
              BoxShadow(
                color: _getTypeColor(type).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getTypeColor(type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getTypeColor(type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.grey[500] : Colors.black87,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patientName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getTypeColor(type),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onComplete,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.check_circle_outline,
                  color: isCompleted ? Colors.green : Colors.grey[400],
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
      case 'medication':
        return Colors.orange;
      case 'control':
      case 'contrôle':
        return Colors.blue;
      case 'procedure':
        return Colors.purple;
      case 'other':
      default:
        return Colors.teal;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
      case 'medication':
        return Icons.medication;
      case 'control':
      case 'contrôle':
        return Icons.medical_services;
      case 'procedure':
        return Icons.healing;
      case 'other':
      default:
        return Icons.assignment;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return 'Médicament';
      case 'control':
        return 'Contrôle';
      case 'procedure':
        return 'Procédure';
      case 'other':
      default:
        return 'Autre';
    }
  }
}

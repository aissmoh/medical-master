import 'package:flutter/material.dart';
import '../../models/tracking_session.dart';

class TrackingSummaryScreen extends StatelessWidget {
  final TrackingSession session;

  const TrackingSummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Récapitulatif du suivi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompletionBanner(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildTimelineCard(),
            const SizedBox(height: 16),
            _buildAllObservationsCard(),
            const SizedBox(height: 16),
            if (session.medicationsGiven.isNotEmpty) ...[
              _buildAllMedicationsCard(),
              const SizedBox(height: 16),
            ],
            if (session.completionNote != null) ...[
              _buildCompletionNoteCard(),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.white),
          const SizedBox(height: 8),
          const Text(
            'Suivi terminé avec succès',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Durée totale: ${session.durationLabel}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.teal.shade50,
              child: Text(
                (session.patientName ?? '?').split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.patientName ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  if (session.patientPhone != null)
                    Text('📞 ${session.patientPhone}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  if (session.patientBloodGroup != null)
                    Text('🩸 ${session.patientBloodGroup}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Début', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                Text('${session.createdAt.day}/${session.createdAt.month}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (session.completedAt != null) ...[
                  Text('Fin', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  Text('${session.completedAt!.day}/${session.completedAt!.month}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    final statuses = TrackingStatus.values;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Évolution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(statuses.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Expanded(
                    child: Container(height: 2, color: Colors.green.shade300),
                  );
                }
                final idx = i ~/ 2;
                final st = statuses[idx];
                final isCompleted = st.index <= session.status.index;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? Colors.green : Colors.grey.shade300,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : const Icon(Icons.more_horiz, color: Colors.white, size: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(st.label, style: TextStyle(fontSize: 9, color: isCompleted ? Colors.green : Colors.grey)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllObservationsCard() {
    final soapTypes = ObservationType.values;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Observations SOAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (session.observations.isEmpty)
              Text('Aucune observation enregistrée', style: TextStyle(color: Colors.grey.shade500))
            else
              ...soapTypes.map((type) {
                final obs = session.observations.where((o) => o.type == type).toList();
                if (obs.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _soapColor(type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${type.label} (${obs.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _soapColor(type),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...obs.map((o) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: _soapColor(type))),
                            Expanded(child: Text(o.content, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAllMedicationsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médicaments administrés (${session.medicationsGiven.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...session.medicationsGiven.map((med) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.medication, color: Colors.teal.shade700, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(med.dosage, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (med.notes != null)
                    Text(med.notes!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionNoteCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Text('Note de clôture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.completionNote!,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _soapColor(ObservationType type) {
    switch (type) {
      case ObservationType.subjective:
        return Colors.purple;
      case ObservationType.objective:
        return Colors.blue;
      case ObservationType.assessment:
        return Colors.orange;
      case ObservationType.plan:
        return Colors.teal;
    }
  }
}

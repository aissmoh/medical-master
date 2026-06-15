import 'package:flutter/material.dart';
import '../../models/tracking_session.dart';
import '../../services/tracking_service.dart';
import 'tracking_summary_screen.dart';

class PatientTrackingScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final int patientAge;
  final String patientGender;

  const PatientTrackingScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.patientAge = 0,
    this.patientGender = '',
  });

  @override
  State<PatientTrackingScreen> createState() => _PatientTrackingScreenState();
}

class _PatientTrackingScreenState extends State<PatientTrackingScreen> {
  TrackingSession? _session;
  bool _loading = true;

  // Form fields
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final _medNameController = TextEditingController();
  final _medDosageController = TextEditingController();
  final _medNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _followUpController.dispose();
    _medNameController.dispose();
    _medDosageController.dispose();
    _medNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadTracking() async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await TrackingService.getActiveTracking(widget.patientId);
      if (res['success'] && res['tracking'] != null) {
        _session = TrackingSession.fromJson(res['tracking']);
        _notesController.text = _session?.notes ?? '';
        _followUpController.text = _session?.followUpPlan ?? '';
      } else {
        _session = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startTracking() async {
    final res = await TrackingService.startTracking(widget.patientId);
    if (res['success'] && res['tracking'] != null) {
      setState(() {
        _session = TrackingSession.fromJson(res['tracking']);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Erreur')),
        );
      }
    }
  }

  Future<void> _addObservation(ObservationType type) async {
    final contentController = TextEditingController();
    String? templateUsed;

    final templates = _getTemplates(type);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Ajouter ${type.label}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (templates.isNotEmpty) ...[
                  const Text('Modèles rapides:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: templates.map((t) => ActionChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        contentController.text = t;
                        templateUsed = t;
                        setDState(() {});
                      },
                    )).toList(),
                  ),
                  const Divider(height: 20),
                ],
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Écrivez votre observation...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'content': contentController.text,
                if (templateUsed != null) 'templateUsed': templateUsed!,
              }),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['content']!.trim().isNotEmpty && _session != null) {
      final obs = Observation(
        type: type,
        content: result['content']!,
        templateUsed: result['templateUsed'],
        recordedAt: DateTime.now(),
      );
      final res = await TrackingService.addObservation(_session!.id, obs);
      if (res['success']) {
        await _loadTracking();
      }
    }
  }

  List<String> _getTemplates(ObservationType type) {
    switch (type) {
      case ObservationType.subjective:
        return [
          'Le patient se sent mieux',
          'Le patient signale une douleur',
          'Le patient a bien dormi',
          'Le patient est fatigué',
          'Le patient n\'a pas d\'appétit',
        ];
      case ObservationType.objective:
        return [
          'TA normotendue, pouls régulier',
          'SpO2 normale, température normale',
          'Bruits respiratoires clairs',
          'Œdème des membres inférieurs',
          'Conscience normale, orienté',
        ];
      case ObservationType.assessment:
        return [
          'État stable, bonne évolution',
          'Légère amélioration constatée',
          'Surveillance continue nécessaire',
          'Risque de complication faible',
          'Patient répond bien au traitement',
        ];
      case ObservationType.plan:
        return [
          'Surveiller les signes vitaux',
          'Réévaluer dans 24h',
          'Administrer traitement prescrit',
          'Repos au lit strict',
          'Préparer la sortie du patient',
        ];
    }
  }

  Future<void> _addMedication() async {
    if (_medNameController.text.trim().isEmpty ||
        _medDosageController.text.trim().isEmpty) {
      return;
    }

    if (_session == null) return;

    final med = MedicationGiven(
      name: _medNameController.text.trim(),
      dosage: _medDosageController.text.trim(),
      givenAt: DateTime.now(),
      notes: _medNotesController.text.trim().isEmpty
          ? null
          : _medNotesController.text.trim(),
    );

    final res = await TrackingService.addMedication(_session!.id, med);
    if (res['success']) {
      _medNameController.clear();
      _medDosageController.clear();
      _medNotesController.clear();
      await _loadTracking();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Médicament enregistré'),
          backgroundColor: res['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStatus(TrackingStatus newStatus) async {
    if (_session == null) return;
    final res = await TrackingService.updateStatus(_session!.id, newStatus);
    if (res['success']) {
      await _loadTracking();
    }
  }

  Future<void> _completeTracking() async {
    if (_session == null) return;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer le suivi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Note de clôture (obligatoire):'),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Raison de la clôture, état final...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('La note de clôture est requise')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await TrackingService.completeTracking(
        _session!.id,
        completionNote: noteController.text.trim(),
      );
      if (res['success']) {
        await _loadTracking();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingSummaryScreen(
                session: TrackingSession.fromJson(res['tracking']),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Erreur')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi - ${widget.patientName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_session != null && _session!.status != TrackingStatus.termine)
            TextButton.icon(
              onPressed: _completeTracking,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Clôturer', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _session == null
              ? _buildNoTrackingView()
              : _session!.status == TrackingStatus.termine
                  ? _buildCompletedView()
                  : _buildActiveTrackingView(),
    );
  }

  Widget _buildNoTrackingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun suivi actif',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Démarrez un nouveau suivi pour ${widget.patientName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer le suivi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Suivi terminé',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ce suivi a été clôturé avec succès.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingSummaryScreen(
                    session: _session!,
                  ),
                ),
              ),
              icon: const Icon(Icons.summarize),
              label: const Text('Voir le récapitulatif'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _startTracking,
              icon: const Icon(Icons.refresh),
              label: const Text('Démarrer un nouveau suivi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrackingView() {
    final s = _session!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(s),
          const SizedBox(height: 16),
          _buildStatusTimeline(s),
          const SizedBox(height: 16),
          _buildVitalSnapshotCard(s),
          const SizedBox(height: 16),
          _buildSOAPSection(s),
          const SizedBox(height: 16),
          _buildMedicationsSection(s),
          const SizedBox(height: 16),
          _buildNotesSection(s),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(TrackingSession s) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _statusColor(s.status).withValues(alpha: 0.15),
              child: Icon(
                _statusIcon(s.status),
                color: _statusColor(s.status),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.patientName}, ${widget.patientAge} ans',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Durée: ${s.durationLabel}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(s.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor(s.status).withValues(alpha: 0.3)),
              ),
              child: Text(
                s.status.label,
                style: TextStyle(
                  color: _statusColor(s.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(TrackingSession s) {
    final statuses = TrackingStatus.values.where((e) => e != TrackingStatus.termine).toList();
    final currentIndex = statuses.indexOf(s.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Évolution du patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              children: List.generate(statuses.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      color: i ~/ 2 < currentIndex
                          ? _statusColor(statuses[i ~/ 2])
                          : Colors.grey.shade300,
                    ),
                  );
                }
                final idx = i ~/ 2;
                final st = statuses[idx];
                final isActive = idx <= currentIndex;
                final isCurrent = idx == currentIndex;
                return GestureDetector(
                  onTap: () {
                    if (isActive && idx != currentIndex) {
                      _updateStatus(st);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isCurrent ? 40 : 32,
                        height: isCurrent ? 40 : 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? _statusColor(st) : Colors.grey.shade200,
                          border: isCurrent
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isCurrent
                              ? [BoxShadow(color: _statusColor(st).withValues(alpha: 0.4), blurRadius: 8)]
                              : null,
                        ),
                        child: Icon(
                          _statusIcon(st),
                          color: Colors.white,
                          size: isCurrent ? 20 : 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        st.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? _statusColor(st) : Colors.grey,
                        ),
                      ),
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

  Widget _buildVitalSnapshotCard(TrackingSession s) {
    final v = s.vitalSnapshot;
    final hasData = v.heartRate != null || v.temperature != null ||
        v.oxygenLevel != null || v.systolicBP != null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Derniers signes vitaux', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (!hasData)
              Text('Aucune donnée vitale disponible',
                  style: TextStyle(color: Colors.grey.shade500))
            else
              Row(
                children: [
                  _vitalTile('♥ ${v.heartRate?.toStringAsFixed(0) ?? "--"}', 'bpm', Colors.red),
                  _vitalTile('🌡 ${v.temperature?.toStringAsFixed(1) ?? "--"}', '°C', Colors.orange),
                  _vitalTile('🫁 ${v.oxygenLevel?.toStringAsFixed(0) ?? "--"}', '%', Colors.blue),
                  _vitalTile(
                    '⬡ ${v.systolicBP?.toString() ?? "--"}/${v.diastolicBP?.toString() ?? "--"}',
                    'mmHg',
                    Colors.purple,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _vitalTile(String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildSOAPSection(TrackingSession s) {
    final soapTypes = ObservationType.values;
    final counts = {
      for (final t in soapTypes) t: s.observations.where((o) => o.type == t).length,
    };
    final totalObservations = s.observations.length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notes SOAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('$totalObservations observations',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: soapTypes.map((t) => Expanded(
                child: GestureDetector(
                  onTap: () => _addObservation(t),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _soapColor(t).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _soapColor(t).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(t.shortLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _soapColor(t),
                              fontSize: 16,
                            )),
                        if (counts[t]! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: _soapColor(t),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${counts[t]}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
            if (totalObservations > 0) ...[
              const SizedBox(height: 12),
              ...s.observations.reversed.take(5).map((obs) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _soapColor(obs.type).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              obs.type.shortLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _soapColor(obs.type),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(obs.recordedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(obs.content, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsSection(TrackingSession s) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Médicaments administrés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (s.medicationsGiven.isEmpty)
              Text('Aucun médicament administré', style: TextStyle(color: Colors.grey.shade500))
            else
              ...List.generate(s.medicationsGiven.length, (i) {
                final med = s.medicationsGiven[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.medication, color: Colors.teal.shade700, size: 20),
                  ),
                  title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${med.dosage}${med.notes != null ? ' · ${med.notes}' : ''}'),
                  trailing: Text(
                    _formatTime(med.givenAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                );
              }),
            const Divider(),
            // Add medication form
            TextField(
              controller: _medNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du médicament',
                hintText: 'ex: Doliprane',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _medDosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'ex: 500mg',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _medNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (opt.)',
                      hintText: 'avant repas',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addMedication,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(TrackingSession s) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notes et plan de suivi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes générales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _followUpController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Plan de suivi',
                hintText: 'Prochaines étapes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.enCours:
        return Colors.orange;
      case TrackingStatus.amelioration:
        return Colors.blue;
      case TrackingStatus.stable:
        return Colors.green;
      case TrackingStatus.termine:
        return Colors.grey;
    }
  }

  IconData _statusIcon(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.enCours:
        return Icons.timelapse;
      case TrackingStatus.amelioration:
        return Icons.trending_up;
      case TrackingStatus.stable:
        return Icons.check_circle_outline;
      case TrackingStatus.termine:
        return Icons.check_circle;
    }
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

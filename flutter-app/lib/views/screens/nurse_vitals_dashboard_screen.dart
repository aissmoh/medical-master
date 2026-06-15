import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/vital_signs_service.dart';

class NurseVitalsDashboardScreen extends StatefulWidget {
  const NurseVitalsDashboardScreen({super.key});

  @override
  State<NurseVitalsDashboardScreen> createState() =>
      _NurseVitalsDashboardScreenState();
}

class _NurseVitalsDashboardScreenState
    extends State<NurseVitalsDashboardScreen> {
  List<Map<String, dynamic>> _allPatients = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  String _selectedTab = 'all'; // 'all', 'alerts', 'critical'

  @override
  void initState() {
    super.initState();
    _loadAllPatients();

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadAllPatients();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllPatients() async {
    try {
      final patients = await VitalSignsService.getAllPatientsVitalSigns();
      if (mounted) {
        setState(() {
          _allPatients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    switch (_selectedTab) {
      case 'critical':
        return _allPatients.where((p) {
          final reading = p['latestReading'] as Map<String, dynamic>?;
          if (reading == null) return false;
          return _hasCriticalAlert(reading);
        }).toList();
      case 'alerts':
        return _allPatients.where((p) {
          final reading = p['latestReading'] as Map<String, dynamic>?;
          if (reading == null) return false;
          return _hasAnyAlert(reading);
        }).toList();
      default:
        return _allPatients;
    }
  }

  bool _hasCriticalAlert(Map<String, dynamic> reading) {
    return reading['oxygenLevel']?['status'] == 'critical' ||
        reading['heartRate']?['status'] == 'critical' ||
        reading['temperature']?['status'] == 'critical' ||
        reading['vertigo']?['status'] == 'critical';
  }

  bool _hasAnyAlert(Map<String, dynamic> reading) {
    return reading['oxygenLevel']?['status'] == 'critical' ||
        reading['heartRate']?['status'] == 'critical' ||
        reading['temperature']?['status'] == 'critical' ||
        reading['vertigo']?['status'] == 'critical' ||
        reading['oxygenLevel']?['status'] == 'warning' ||
        reading['heartRate']?['status'] == 'warning' ||
        reading['temperature']?['status'] == 'warning' ||
        reading['vertigo']?['status'] == 'warning';
  }

  int get _criticalCount {
    return _allPatients.where((p) {
      final reading = p['latestReading'] as Map<String, dynamic>?;
      if (reading == null) return false;
      return _hasCriticalAlert(reading);
    }).length;
  }

  int get _warningCount {
    return _allPatients.where((p) {
      final reading = p['latestReading'] as Map<String, dynamic>?;
      if (reading == null) return false;
      return _hasAnyAlert(reading) && !_hasCriticalAlert(reading);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surveillance des Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllPatients,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          _buildStatsRow(),

          // Tabs
          _buildTabBar(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorWidget()
                : _filteredPatients.isEmpty
                ? _buildEmptyWidget()
                : RefreshIndicator(
                    onRefresh: _loadAllPatients,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredPatients.length,
                      itemBuilder: (context, index) {
                        return _buildPatientCard(_filteredPatients[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Patients',
              _allPatients.length.toString(),
              Icons.people,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Critiques',
              _criticalCount.toString(),
              Icons.warning,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Avertissements',
              _warningCount.toString(),
              Icons.notifications,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip('Tous', 'all', Icons.people_outline),
            const SizedBox(width: 8),
            _buildTabChip(
              'Alertes',
              'alerts',
              Icons.notifications,
              badge: _criticalCount + _warningCount,
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              'Critiques',
              'critical',
              Icons.warning,
              badge: _criticalCount,
              badgeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(
    String label,
    String value,
    IconData icon, {
    int badge = 0,
    Color badgeColor = Colors.red,
  }) {
    final isSelected = _selectedTab == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(label),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTab = value;
          });
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllPatients,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 'all'
                ? 'Aucun patient avec des données'
                : 'Aucune alerte ${_selectedTab == 'critical' ? 'critique' : ''}',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patientData) {
    final patient = patientData['patient'] as Map<String, dynamic>?;
    final reading = patientData['latestReading'] as Map<String, dynamic>?;

    if (patient == null) return const SizedBox.shrink();

    final patientName = patient['name'] ?? 'Patient inconnu';
    final patientEmail = patient['email'] ?? '';
    final patientId = patient['_id']?.toString() ?? '';

    final hasCritical = reading != null && _hasCriticalAlert(reading);
    final hasWarning = reading != null && _hasAnyAlert(reading) && !hasCritical;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: hasCritical ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasCritical
            ? const BorderSide(color: Colors.red, width: 2)
            : hasWarning
            ? const BorderSide(color: Colors.orange, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showPatientDetails(patientId, patientName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: hasCritical
                        ? Colors.red.shade100
                        : hasWarning
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    child: Icon(
                      Icons.person,
                      color: hasCritical
                          ? Colors.red
                          : hasWarning
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          patientEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCritical || hasWarning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasCritical ? Colors.red : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasCritical ? 'CRITIQUE' : 'ATTENTION',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (reading != null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (reading['oxygenLevel'] != null)
                      _buildVitalChip(
                        'O₂',
                        '${reading['oxygenLevel']['value'].toStringAsFixed(0)}%',
                        reading['oxygenLevel']['status'],
                      ),
                    if (reading['heartRate'] != null)
                      _buildVitalChip(
                        '❤️',
                        '${reading['heartRate']['value'].toStringAsFixed(0)}',
                        reading['heartRate']['status'],
                      ),
                    if (reading['temperature'] != null)
                      _buildVitalChip(
                        '🌡️',
                        '${reading['temperature']['value'].toStringAsFixed(1)}°C',
                        reading['temperature']['status'],
                      ),
                    if (reading['vertigo'] != null)
                      _buildVitalChip(
                        '🌀',
                        '${reading['vertigo']['value'].toStringAsFixed(0)}',
                        reading['vertigo']['status'],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dernière mesure: ${_formatDateTime(reading['measuredAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ] else
                const Text(
                  'Aucune donnée récente',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, String status) {
    Color color;
    switch (status) {
      case 'critical':
        color = Colors.red;
        break;
      case 'warning':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showPatientDetails(String patientId, String patientName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PatientVitalsDetailSheet(
        patientId: patientId,
        patientName: patientName,
      ),
    );
  }
}

// Bottom sheet for patient details
class PatientVitalsDetailSheet extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientVitalsDetailSheet({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientVitalsDetailSheet> createState() =>
      _PatientVitalsDetailSheetState();
}

class _PatientVitalsDetailSheetState extends State<PatientVitalsDetailSheet> {
  VitalSignsReading? _latestReading;
  VitalStats? _stats;
  List<VitalSignsReading> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final results = await Future.wait([
      VitalSignsService.getPatientVitalSigns(widget.patientId),
      VitalSignsService.getPatientStats(widget.patientId, days: 7),
      VitalSignsService.getPatientHistory(widget.patientId, days: 7),
    ]);

    if (mounted) {
      setState(() {
        _latestReading = results[0] as VitalSignsReading?;
        _stats = results[1] as VitalStats?;
        _history = results[2] as List<VitalSignsReading>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patientName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${widget.patientId.substring(0, 8)}...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Latest reading
                            const Text(
                              'Dernière mesure',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_latestReading != null) ...[
                              _buildLatestReadingCard(),
                              const SizedBox(height: 24),
                            ],

                            // Stats
                            const Text(
                              'Statistiques (7 jours)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatsSection(),
                            const SizedBox(height: 24),

                            // History
                            const Text(
                              'Historique récent',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildHistoryList(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestReadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                if (_latestReading!.oxygenLevel != null)
                  _buildBigVitalDisplay(
                    'Oxygène',
                    '${_latestReading!.oxygenLevel?.value.toStringAsFixed(0)}%',
                    'SpO2',
                    Colors.blue,
                    _latestReading!.oxygenLevel!.status,
                  ),
                if (_latestReading!.heartRate != null)
                  _buildBigVitalDisplay(
                    'Fréquence',
                    '${_latestReading!.heartRate?.value.toStringAsFixed(0)}',
                    'BPM',
                    Colors.red,
                    _latestReading!.heartRate!.status,
                  ),
                if (_latestReading!.temperature != null)
                  _buildBigVitalDisplay(
                    'Température',
                    '${_latestReading!.temperature?.value.toStringAsFixed(1)}',
                    '°C',
                    Colors.orange,
                    _latestReading!.temperature!.status,
                  ),
                if (_latestReading!.vertigo != null)
                  _buildBigVitalDisplay(
                    'Vertige',
                    '${_latestReading!.vertigo?.value.toStringAsFixed(0)}',
                    'RPM',
                    Colors.purple,
                    _latestReading!.vertigo!.status,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigVitalDisplay(
    String label,
    String value,
    String unit,
    Color color,
    String status,
  ) {
    Color statusColor;
    switch (status) {
      case 'critical':
        statusColor = Colors.red;
        break;
      case 'warning':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.green;
    }

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: statusColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          if (status != 'normal')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status == 'critical' ? 'CRITIQUE' : 'ATTENTION',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune statistique disponible'),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Mesures', _stats!.totalReadings.toString()),
                _buildStatItem(
                  'Alertes critiques',
                  _stats!.criticalAlerts.toString(),
                  color: Colors.red,
                ),
                _buildStatItem(
                  'Avertissements',
                  _stats!.warningAlerts.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_stats!.oxygenLevel != null)
          _buildMetricStatsCard('Oxygène (%)', _stats!.oxygenLevel!),
        if (_stats!.heartRate != null)
          _buildMetricStatsCard(
            'Fréquence Cardiaque (BPM)',
            _stats!.heartRate!,
          ),
        if (_stats!.temperature != null)
          _buildMetricStatsCard('Température (°C)', _stats!.temperature!),
        if (_stats!.vertigo != null)
          _buildMetricStatsCard('Vertige (RPM)', _stats!.vertigo!),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMetricStatsCard(String label, MetricStats stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Moyenne', stats.average.toStringAsFixed(1)),
                _buildMiniStat('Min', stats.min.toStringAsFixed(1)),
                _buildMiniStat('Max', stats.max.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun historique disponible'),
        ),
      );
    }

    return Column(
      children: _history.map((reading) => _buildHistoryCard(reading)).toList(),
    );
  }

  Widget _buildHistoryCard(VitalSignsReading reading) {
    final hasAlerts = reading.hasCriticalAlert || reading.hasWarningAlert;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: hasAlerts
            ? BorderSide(
                color: reading.hasCriticalAlert ? Colors.red : Colors.orange,
              )
            : BorderSide.none,
      ),
      child: ListTile(
        leading: hasAlerts
            ? Icon(
                Icons.warning,
                color: reading.hasCriticalAlert ? Colors.red : Colors.orange,
              )
            : const Icon(Icons.check_circle, color: Colors.green),
        title: Text(
          '${reading.measuredAt.day}/${reading.measuredAt.month}/${reading.measuredAt.year} ${reading.measuredAt.hour}:${reading.measuredAt.minute.toString().padLeft(2, '0')}',
        ),
        subtitle: Wrap(
          spacing: 8,
          children: [
            if (reading.oxygenLevel != null)
              Text('O₂: ${reading.oxygenLevel?.value.toStringAsFixed(0)}%'),
            if (reading.heartRate != null)
              Text('FC: ${reading.heartRate?.value.toStringAsFixed(0)}'),
            if (reading.temperature != null)
              Text('T: ${reading.temperature?.value.toStringAsFixed(1)}°C'),
          ],
        ),
      ),
    );
  }
}

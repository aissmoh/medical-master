import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/vital_signs_service.dart';

class PatientVitalSignsScreen extends StatefulWidget {
  const PatientVitalSignsScreen({Key? key}) : super(key: key);

  @override
  State<PatientVitalSignsScreen> createState() => _PatientVitalSignsScreenState();
}

class _PatientVitalSignsScreenState extends State<PatientVitalSignsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _oxygenController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _vertigoController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  List<VitalAlert>? _lastAlerts;
  VitalSignsReading? _latestReading;

  @override
  void initState() {
    super.initState();
    _loadLatestReading();
  }

  Future<void> _loadLatestReading() async {
    final reading = await VitalSignsService.getMyLatestVitalSigns();
    if (mounted) {
      setState(() {
        _latestReading = reading;
      });
    }
  }

  Future<void> _submitVitalSigns() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastAlerts = null;
    });

    try {
      // Parse values
      final oxygenLevel = _oxygenController.text.isNotEmpty 
          ? double.parse(_oxygenController.text) 
          : null;
      final heartRate = _heartRateController.text.isNotEmpty 
          ? double.parse(_heartRateController.text) 
          : null;
      final temperature = _temperatureController.text.isNotEmpty 
          ? double.parse(_temperatureController.text) 
          : null;
      final vertigo = _vertigoController.text.isNotEmpty 
          ? double.parse(_vertigoController.text) 
          : null;

      Map<String, int>? bloodPressure;
      if (_systolicController.text.isNotEmpty && _diastolicController.text.isNotEmpty) {
        bloodPressure = {
          'systolic': int.parse(_systolicController.text),
          'diastolic': int.parse(_diastolicController.text),
        };
      }

      final result = await VitalSignsService.recordVitalSigns(
        oxygenLevel: oxygenLevel,
        heartRate: heartRate,
        temperature: temperature,
        vertigo: vertigo,
        bloodPressure: bloodPressure,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (result['success'] == true) {
        final reading = result['data'] as VitalSignsReading;
        final alerts = result['alerts'] as List<dynamic>?;

        setState(() {
          _latestReading = reading;
          _lastAlerts = reading.alerts;
          _isLoading = false;
        });

        // Show result dialog
        _showResultDialog(reading, alerts);

        // Clear form
        _clearForm();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Erreur lors de l\'enregistrement';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _oxygenController.clear();
    _heartRateController.clear();
    _temperatureController.clear();
    _vertigoController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _notesController.clear();
  }

  void _showResultDialog(VitalSignsReading reading, List<dynamic>? alerts) {
    final hasAlerts = reading.hasCriticalAlert || reading.hasWarningAlert;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasAlerts ? Icons.warning : Icons.check_circle,
              color: hasAlerts ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(hasAlerts ? 'Alertes détectées' : 'Succès'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasAlerts 
                ? '${reading.alerts.length} signe(s) vital(aux) anormal(aux) détecté(s):'
                : 'Tous vos signes vitaux sont normaux.',
            ),
            if (hasAlerts) ...[
              const SizedBox(height: 16),
              ...reading.alerts.map((alert) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.severity == 'critical' 
                    ? Colors.red.shade50 
                    : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.severity == 'critical' 
                      ? Colors.red 
                      : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: alert.severity == 'critical' 
                        ? Colors.red 
                        : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${alert.type}: ${alert.message}',
                        style: TextStyle(
                          color: alert.severity == 'critical' 
                            ? Colors.red.shade800 
                            : Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
            const SizedBox(height: 16),
            if (hasAlerts)
              const Text(
                'Votre infirmier a été notifié.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHistory() async {
    final history = await VitalSignsService.getMyVitalSignsHistory(days: 7);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Historique des 7 derniers jours',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: history.isEmpty
                    ? const Center(
                        child: Text('Aucune donnée disponible'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final reading = history[index];
                          return _buildHistoryCard(reading);
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(VitalSignsReading reading) {
    final hasAlerts = reading.hasCriticalAlert || reading.hasWarningAlert;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasAlerts 
          ? BorderSide(color: reading.hasCriticalAlert ? Colors.red : Colors.orange)
          : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reading.measuredAt.day}/${reading.measuredAt.month}/${reading.measuredAt.year} ${reading.measuredAt.hour}:${reading.measuredAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                if (hasAlerts)
                  Icon(
                    Icons.warning,
                    color: reading.hasCriticalAlert ? Colors.red : Colors.orange,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (reading.oxygenLevel != null)
                  _buildMiniMetric('O₂', '${reading.oxygenLevel?.value.toStringAsFixed(0)}%', 
                    reading.oxygenLevel!.status),
                if (reading.heartRate != null)
                  _buildMiniMetric('❤️', '${reading.heartRate?.value.toStringAsFixed(0)} bpm', 
                    reading.heartRate!.status),
                if (reading.temperature != null)
                  _buildMiniMetric('🌡️', '${reading.temperature?.value.toStringAsFixed(1)}°C', 
                    reading.temperature!.status),
                if (reading.vertigo != null)
                  _buildMiniMetric('🌀', '${reading.vertigo?.value.toStringAsFixed(0)} rpm', 
                    reading.vertigo!.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String icon, String value, String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$icon $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Signes Vitaux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
            tooltip: 'Historique',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Latest reading card
              if (_latestReading != null) _buildLatestReadingCard(),
              
              const SizedBox(height: 24),
              
              const Text(
                'Nouvelle mesure',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez vos signes vitaux actuels:',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Oxygène
              _buildVitalCard(
                icon: Icons.air,
                title: 'Oxygène',
                subtitle: 'SpO2 (%)',
                color: Colors.blue,
                controller: _oxygenController,
                min: 70,
                max: 100,
                hint: '95-100',
              ),

              const SizedBox(height: 16),

              // Heart Rate
              _buildVitalCard(
                icon: Icons.favorite,
                title: 'Fréquence Cardiaque',
                subtitle: 'BPM (battements/min)',
                color: Colors.red,
                controller: _heartRateController,
                min: 40,
                max: 200,
                hint: '60-100',
              ),

              const SizedBox(height: 16),

              // Temperature
              _buildVitalCard(
                icon: Icons.thermostat,
                title: 'Température',
                subtitle: '°C',
                color: Colors.orange,
                controller: _temperatureController,
                min: 35,
                max: 42,
                hint: '36.1-37.2',
                allowDecimal: true,
              ),

              const SizedBox(height: 16),

              // Vertigo
              _buildVitalCard(
                icon: Icons.rotate_right,
                title: 'Vertige / Équilibre',
                subtitle: 'RPM (rotations/min)',
                color: Colors.purple,
                controller: _vertigoController,
                min: 0,
                max: 100,
                hint: '0-20',
              ),

              const SizedBox(height: 16),

              // Blood Pressure (optional)
              _buildBloodPressureCard(),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Comment vous sentez-vous?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 3,
                maxLength: 500,
              ),

              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitVitalSigns,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Enregistrer mes signes vitaux',
                        style: TextStyle(fontSize: 16),
                      ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestReadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dernière mesure',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_latestReading!.measuredAt.day}/${_latestReading!.measuredAt.month} ${_latestReading!.measuredAt.hour}:${_latestReading!.measuredAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_latestReading!.oxygenLevel != null)
                  _buildReadingChip(
                    'O₂',
                    '${_latestReading!.oxygenLevel?.value.toStringAsFixed(0)}%',
                    _latestReading!.oxygenLevel!.status,
                  ),
                if (_latestReading!.heartRate != null)
                  _buildReadingChip(
                    '❤️',
                    '${_latestReading!.heartRate?.value.toStringAsFixed(0)}',
                    _latestReading!.heartRate!.status,
                  ),
                if (_latestReading!.temperature != null)
                  _buildReadingChip(
                    '🌡️',
                    '${_latestReading!.temperature?.value.toStringAsFixed(1)}°C',
                    _latestReading!.temperature!.status,
                  ),
                if (_latestReading!.vertigo != null)
                  _buildReadingChip(
                    '🌀',
                    '${_latestReading!.vertigo?.value.toStringAsFixed(0)}',
                    _latestReading!.vertigo!.status,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingChip(String label, String value, String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
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
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required TextEditingController controller,
    required double min,
    required double max,
    required String hint,
    bool allowDecimal = false,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: allowDecimal,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final number = double.tryParse(value);
                  if (number == null) return 'Invalide';
                  if (number < min || number > max) {
                    return 'Entre $min et $max';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodPressureCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: Colors.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pression Artérielle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'mmHg (optionnel)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Systolique',
                      hintText: '120',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final number = int.tryParse(value);
                      if (number == null) return 'Invalide';
                      if (number < 50 || number > 250) {
                        return '50-250';
                      }
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Diastolique',
                      hintText: '80',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final number = int.tryParse(value);
                      if (number == null) return 'Invalide';
                      if (number < 30 || number > 150) {
                        return '30-150';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _oxygenController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _vertigoController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

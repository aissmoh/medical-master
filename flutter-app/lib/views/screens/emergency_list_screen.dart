import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/emergency_service.dart';

class EmergencyListScreen extends StatefulWidget {
  const EmergencyListScreen({super.key});

  @override
  State<EmergencyListScreen> createState() => _EmergencyListScreenState();
}

class _EmergencyListScreenState extends State<EmergencyListScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  List<Emergency> _emergencies = [];
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Rafraîchir toutes les 10 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadEmergencies();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Permission GPS refusée définitivement';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      _loadEmergencies();
    } catch (e) {
      setState(() {
        _error = 'Erreur GPS: $e';
      });
    }
  }

  Future<void> _loadEmergencies() async {
    try {
      if (_isLoading && _emergencies.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });
      }

      final emergencies = await _emergencyService.getActiveEmergencies(
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
      );

      if (mounted) {
        setState(() {
          _emergencies = emergencies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptEmergency(String emergencyId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _emergencyService.acceptEmergency(emergencyId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Urgence acceptée! Rendez-vous sur place.'),
          backgroundColor: Colors.green,
        ),
      );

      _loadEmergencies();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'heart_attack':
        return Colors.red;
      case 'fall':
        return Colors.orange;
      case 'accident':
        return Colors.redAccent;
      case 'breathing':
        return Colors.blue;
      case 'bleeding':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'heart_attack':
        return Icons.favorite;
      case 'fall':
        return Icons.person_off;
      case 'accident':
        return Icons.car_crash;
      case 'breathing':
        return Icons.air;
      case 'bleeding':
        return Icons.water_drop;
      default:
        return Icons.warning;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'heart_attack':
        return 'Crise cardiaque';
      case 'fall':
        return 'Chute';
      case 'accident':
        return 'Accident';
      case 'breathing':
        return 'Difficulté respiratoire';
      case 'bleeding':
        return 'Saignement';
      default:
        return 'Autre urgence';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'in_progress':
        return 'En cours';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'accepted':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.red[600],
        elevation: 0,
        title: const Text(
          'Urgences actives',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEmergencies,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _emergencies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _emergencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEmergencies,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_emergencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune urgence active',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tout va bien!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmergencies,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emergencies.length,
        itemBuilder: (context, index) {
          final emergency = _emergencies[index];
          return _buildEmergencyCard(emergency);
        },
      ),
    );
  }

  Widget _buildEmergencyCard(Emergency emergency) {
    final typeColor = _getTypeColor(emergency.type);
    final patientName = emergency.patient['name']?.toString() ?? 'Patient inconnu';
    final distance = emergency.distance;
    final isPending = emergency.status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec type et statut
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(emergency.type),
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeLabel(emergency.type),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(emergency.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusLabel(emergency.status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(emergency.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const Divider(height: 24),

            // Info patient
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'GPS: ${emergency.location['lat']?.toStringAsFixed(4)}, ${emergency.location['lng']?.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (emergency.description != null && emergency.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emergency.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Bouton d'action
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptEmergency(emergency.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.medical_services),
                  label: const Text(
                    'ACCEPTER CETTE URGENCE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Urgence déjà prise en charge',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

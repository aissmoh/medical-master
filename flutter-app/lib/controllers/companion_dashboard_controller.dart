import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/nurse_service.dart';
import '../services/socket_service.dart';

class CompanionDashboardController extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _patients = [];
  List<dynamic> _tasks = [];
  List<dynamic> _alerts = [];
  Map<String, dynamic>? _stats;
  String _companionName = 'Sofia Martinez';
  int _pendingNotifications = 3;
  
  StreamSubscription? _vitalsSubscription;
  final Map<String, Map<String, dynamic>> _liveVitals = {};

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<dynamic> get patients => _patients;
  List<dynamic> get tasks => _tasks;
  List<dynamic> get alerts => _alerts;
  Map<String, dynamic>? get stats => _stats;
  String get companionName => _companionName;
  int get pendingNotifications => _pendingNotifications;
  Map<String, Map<String, dynamic>> get liveVitals => _liveVitals;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final patientsResult = await NurseService.getMyPatients();
      if (patientsResult['success']) {
        _patients = patientsResult['data'] ?? patientsResult['patients'] ?? [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void startListeningToVitals() {
    final socketService = SocketService();
    socketService.connect();
    
    socketService.subscribeAllVitals();
    
    _vitalsSubscription = socketService.onVitalsUpdate.listen((data) {
      final patientId = data['patientId']?.toString();
      if (patientId != null && data['data'] != null) {
        _liveVitals[patientId] = Map<String, dynamic>.from(data['data']);
        
        final alerts = data['alerts'] as List?;
        if (alerts != null && alerts.isNotEmpty) {
          for (final alert in alerts) {
            _alerts.add({
              'patientId': patientId,
              'type': alert['type'],
              'severity': alert['severity'],
              'message': alert['message'],
              'value': alert['value'],
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }
        
        _updatePatientVitals(patientId, data['data']);
        notifyListeners();
      }
    });
  }

  void stopListeningToVitals() {
    _vitalsSubscription?.cancel();
    _vitalsSubscription = null;
    SocketService().unsubscribeAllVitals();
  }

  void _updatePatientVitals(String patientId, Map<String, dynamic> vitalsData) {
    for (int i = 0; i < _patients.length; i++) {
      final patient = _patients[i];
      if (patient['_id']?.toString() == patientId || patient['id']?.toString() == patientId) {
        _patients[i] = {
          ...patient,
          'latestVitals': vitalsData,
        };
        break;
      }
    }
  }

  Future<void> refreshData() async {
    await loadDashboardData();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    stopListeningToVitals();
    super.dispose();
  }
}

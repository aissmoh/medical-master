import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/patient_vital.dart';
import '../services/auth_storage_service.dart';
import '../services/patient_service.dart';
import '../services/socket_service.dart';
import '../services/vital_signs_service.dart';

class PatientDashboardController extends ChangeNotifier {
  List<PatientVital> _vitals = [];
  int _selectedIndex = 0;
  String _patientName = '';
  bool _isLoadingName = false;
  String? _profileImageUrl;
  
  StreamSubscription? _vitalsSubscription;

  int get selectedIndex => _selectedIndex;
  String get patientName => _patientName.isEmpty ? 'Patient' : _patientName;
  String get dashboardTitle => 'Vue clinique du patient';
  String get dashboardSubtitle =>
      'Surveillez le coeur, la respiration et la temperature en temps reel.';
  List<PatientVital> get vitals => List.unmodifiable(_vitals);
  int get stableVitalsCount => _vitals.length;
  String get latestUpdate =>
      _vitals.isNotEmpty ? _vitals.first.updatedAt : '';
  bool get isLoadingName => _isLoadingName;
  String? get profileImageUrl => _profileImageUrl;

  Future<void> loadPatientName() async {
    if (_isLoadingName) return;

    _isLoadingName = true;

    try {
      final name = await const AuthStorageService().getName();
      if (name != null && name.isNotEmpty) {
        _patientName = name;
        notifyListeners();
      }
    } catch (e) {
      print('Erreur chargement nom patient: $e');
    } finally {
      _isLoadingName = false;
    }
  }

  Future<void> loadProfileAndVitals() async {
    try {
      final profileRes = await PatientService.getProfile();
      if (profileRes['success'] == true && profileRes['data'] != null) {
        final data = profileRes['data'] as Map<String, dynamic>;
        _profileImageUrl = data['profileImage']?.toString();
        if (data['name']?.toString() != null) {
          _patientName = data['name'].toString();
          await const AuthStorageService().saveName(_patientName);
        }
      }
    } catch (_) {}

    try {
      final latest = await VitalSignsService.getMyLatestVitalSigns();
      if (latest != null) {
        _updateVitalsFromReading(latest);
      }
    } catch (_) {}

    notifyListeners();
  }

  void startListeningToVitals() {
    final socketService = SocketService();
    socketService.connect();
    
    _vitalsSubscription = socketService.onVitalsUpdate.listen((data) {
      final vitalsData = data['data'];
      if (vitalsData != null) {
        try {
          final reading = VitalSignsReading.fromJson(vitalsData);
          _updateVitalsFromReading(reading);
          notifyListeners();
        } catch (e) {
          print('Error parsing vitals update: $e');
        }
      }
    });
  }

  void stopListeningToVitals() {
    _vitalsSubscription?.cancel();
    _vitalsSubscription = null;
  }

  void _updateVitalsFromReading(VitalSignsReading latest) {
    final list = <PatientVital>[];

    if (latest.oxygenLevel != null) {
      list.add(PatientVital(
        type: VitalType.respiration,
        title: 'Oxygene',
        value: latest.oxygenLevel!.value.toString(),
        unit: latest.oxygenLevel!.unit,
        status: latest.oxygenLevel!.status,
        referenceRange: 'Reference 95-100%',
        observation: 'Saturation en oxygene.',
        updatedAt: 'Derniere mesure',
      ));
    }
    if (latest.heartRate != null) {
      list.add(PatientVital(
        type: VitalType.heart,
        title: 'Coeur',
        value: latest.heartRate!.value.toString(),
        unit: latest.heartRate!.unit,
        status: latest.heartRate!.status,
        referenceRange: 'Reference 60-100 bpm',
        observation: 'Rythme cardiaque.',
        updatedAt: 'Derniere mesure',
      ));
    }
    if (latest.temperature != null) {
      list.add(PatientVital(
        type: VitalType.temperature,
        title: 'Temperature',
        value: latest.temperature!.value.toString(),
        unit: latest.temperature!.unit,
        status: latest.temperature!.status,
        referenceRange: 'Reference 36.1-37.2 C',
        observation: 'Temperature corporelle.',
        updatedAt: 'Derniere mesure',
      ));
    }

    if (list.isNotEmpty) {
      _vitals = list;
    }
  }

  Future<void> updatePatientName(String name) async {
    _patientName = name;
    await const AuthStorageService().saveName(name);
    notifyListeners();
  }

  void onTabChanged(int index) {
    if (_selectedIndex == index) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListeningToVitals();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../services/nurse_service.dart';
import '../services/task_service.dart';
import '../services/auth_storage_service.dart';

enum PatientStatus { stable, critical, monitoring }

class PatientLocation {
  final double latitude;
  final double longitude;
  final String address;
  final DateTime lastUpdated;

  PatientLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.lastUpdated,
  });
}

class AlertMessage {
  final String id;
  final String patientId;
  final String patientName;
  final String type;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  AlertMessage({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory AlertMessage.fromJson(Map<String, dynamic> json) {
    return AlertMessage(
      id: json['_id']?.toString() ?? '',
      patientId: json['patientId'] is Map ? json['patientId']['_id']?.toString() ?? '' : json['patientId']?.toString() ?? '',
      patientName: json['patientId'] is Map ? json['patientId']['name']?.toString() ?? 'Inconnu' : 'Inconnu',
      type: json['type']?.toString() ?? 'emergency',
      message: json['message']?.toString() ?? '',
      timestamp: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      isRead: json['status'] == 'acknowledged' || json['status'] == 'resolved',
    );
  }
}

// NEW: Medication Model
class Medication {
  final String id;
  final String patientId;
  final String patientName;
  final String name;
  final String dosage;
  final String frequency;
  final String? instructions;
  final DateTime scheduledTime;
  final bool isGiven;
  final DateTime? givenAt;
  final String? notes;

  Medication({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.instructions,
    required this.scheduledTime,
    this.isGiven = false,
    this.givenAt,
    this.notes,
  });
}

// NEW: Emergency Alert Model
class EmergencyAlert {
  final String id;
  final String patientId;
  final String patientName;
  final String type; // 'critical', 'emergency', 'warning'
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isResolved;
  final String? actionTaken;

  EmergencyAlert({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isResolved = false,
    this.actionTaken,
  });
}

// NEW: Care Request Model
class CareRequest {
  final String id;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final String? patientEmail;
  final String? patientBloodGroup;
  final String? patientChamber;
  final String? patientBed;
  final DateTime createdAt;
  final String status;
  final String reason;
  final String urgency;
  final List<String> symptoms;
  final double? locationLat;
  final double? locationLng;
  final String locationAddress;
  final String preferredContactTime;
  final String patientNotes;

  CareRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    this.patientEmail,
    this.patientBloodGroup,
    this.patientChamber,
    this.patientBed,
    required this.createdAt,
    required this.status,
    this.reason = '',
    this.urgency = 'medium',
    this.symptoms = const [],
    this.locationLat,
    this.locationLng,
    this.locationAddress = '',
    this.preferredContactTime = '',
    this.patientNotes = '',
  });

  String get requestAge {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
    return "Il y a ${diff.inDays}j";
  }

  Color get urgencyColor {
    switch (urgency) {
      case 'low': return const Color(0xFF4CAF50);
      case 'medium': return const Color(0xFFFFA726);
      case 'high': return const Color(0xFFEF5350);
      case 'emergency': return const Color(0xFFD32F2F);
      default: return Colors.grey;
    }
  }

  String get urgencyLabel {
    switch (urgency) {
      case 'low': return 'Faible';
      case 'medium': return 'Moyenne';
      case 'high': return 'Haute';
      case 'emergency': return 'Urgence';
      default: return urgency;
    }
  }

  IconData get urgencyIcon {
    switch (urgency) {
      case 'low': return Icons.arrow_downward_rounded;
      case 'medium': return Icons.remove_rounded;
      case 'high': return Icons.arrow_upward_rounded;
      case 'emergency': return Icons.warning_rounded;
      default: return Icons.help_outline;
    }
  }

  factory CareRequest.fromJson(Map<String, dynamic> json) {
    final patient = json['patientId'] is Map ? json['patientId'] : null;
    final roomInfo = patient?['roomInfo'];
    final location = json['location'] is Map ? json['location'] : null;
    final rawSymptoms = json['symptoms'];
    final List<String> symptomsList = [];
    if (rawSymptoms is List) {
      for (var s in rawSymptoms) {
        symptomsList.add(s.toString());
      }
    }
    return CareRequest(
      id: json['_id']?.toString() ?? '',
      patientId: patient != null ? patient['_id']?.toString() ?? '' : json['patientId']?.toString() ?? '',
      patientName: patient != null ? patient['name']?.toString() ?? 'Inconnu' : 'Inconnu',
      patientPhone: patient != null ? patient['phone']?.toString() ?? '--' : '--',
      patientEmail: patient != null ? patient['email']?.toString() : null,
      patientBloodGroup: patient != null ? patient['groupeSanguin']?.toString() : null,
      patientChamber: roomInfo != null ? roomInfo['chamber']?.toString() : null,
      patientBed: roomInfo != null ? roomInfo['bed']?.toString() : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? 'medium',
      symptoms: symptomsList,
      locationLat: location != null ? (location['lat'] as num?)?.toDouble() : null,
      locationLng: location != null ? (location['lng'] as num?)?.toDouble() : null,
      locationAddress: location != null ? (location['address']?.toString() ?? '') : '',
      preferredContactTime: json['preferredContactTime']?.toString() ?? '',
      patientNotes: json['patientNotes']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isFromPatient;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isFromPatient,
  });
}

class TaskItem {
  final String id;
  final String patientId;
  final String patientName;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final bool isCompleted;
  final String type; // 'medication', 'checkup', 'exercise', 'meal'
  final String? notes;

  TaskItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    required this.description,
    required this.scheduledTime,
    this.isCompleted = false,
    required this.type,
    this.notes,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['_id']?.toString() ?? '',
      patientId: json['patientId'] is Map ? json['patientId']['_id']?.toString() ?? '' : json['patientId']?.toString() ?? '',
      patientName: json['patientId'] is Map ? json['patientId']['name']?.toString() ?? 'Inconnu' : 'Inconnu',
      title: json['title']?.toString() ?? 'Tâche',
      description: json['description']?.toString() ?? '',
      scheduledTime: json['scheduledTime'] != null ? DateTime.parse(json['scheduledTime']) : (json['dueDate'] != null ? DateTime.parse(json['dueDate']) : DateTime.now()),
      isCompleted: json['status'] == 'completed',
      type: json['type']?.toString() ?? 'medication',
      notes: json['notes']?.toString(),
    );
  }
}

class DashboardStats {
  final int totalPatients;
  final int criticalPatients;
  final int medicationsGiven;
  final int pendingTasks;
  final double completionRate;
  final List<Map<String, dynamic>> dailyActivity;

  DashboardStats({
    required this.totalPatients,
    required this.criticalPatients,
    required this.medicationsGiven,
    required this.pendingTasks,
    required this.completionRate,
    required this.dailyActivity,
  });
}

class DoctorInfo {
  final String name;
  final String phone;
  final String specialty;

  DoctorInfo({
    required this.name,
    required this.phone,
    required this.specialty,
  });
}

class PatientSummary {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String? profileImage;
  final String roomNumber;
  final PatientStatus status;
  final String lastHeartRate;
  final String lastTemperature;
  final String lastOxygen;
  final String? nextMedication;
  final String medicationTime;
  final DateTime lastUpdate;
  final PatientLocation? location;
  final DoctorInfo? doctor;

  PatientSummary({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.profileImage,
    required this.roomNumber,
    required this.status,
    required this.lastHeartRate,
    required this.lastTemperature,
    required this.lastOxygen,
    this.nextMedication,
    required this.medicationTime,
    required this.lastUpdate,
    this.location,
    this.doctor,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    final vitals = json['latestVitals'] as Map<String, dynamic>?;
    
    return PatientSummary(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Inconnu',
      age: json['age'] ?? 40,
      gender: json['gender']?.toString() ?? 'Non spécifié',
      roomNumber: json['roomInfo']?.toString() ?? 'Non assignée',
      status: PatientStatus.stable, // Can be computed based on vitals
      lastHeartRate: vitals != null && vitals['heartRate'] != null ? '${vitals['heartRate']['value']} bpm' : '--',
      lastTemperature: vitals != null && vitals['temperature'] != null ? '${vitals['temperature']['value']}°C' : '--',
      lastOxygen: vitals != null && vitals['oxygenLevel'] != null ? '${vitals['oxygenLevel']['value']}%' : '--',
      nextMedication: null,
      medicationTime: '--',
      lastUpdate: vitals != null && vitals['measuredAt'] != null ? DateTime.parse(vitals['measuredAt']) : DateTime.now(),
      location: json['location'] != null
          ? PatientLocation(
              latitude: (json['location']['lat'] as num?)?.toDouble() ?? 0.0,
              longitude: (json['location']['lng'] as num?)?.toDouble() ?? 0.0,
              address: json['location']['address']?.toString() ?? '',
              lastUpdated: json['location']['lastUpdated'] != null
                  ? DateTime.parse(json['location']['lastUpdated'])
                  : DateTime.now(),
            )
          : null,
    );
  }
}

class CompanionController extends ChangeNotifier {
  String _companionName = 'Chargement...';
  int _pendingNotifications = 0;
  int _totalPatients = 0;
  int _pendingMedications = 0;
  int _criticalAlerts = 0;
  bool isLoading = false;

  List<PatientSummary> _patients = [];
  List<AlertMessage> _alerts = [];
  List<TaskItem> _tasks = [];
  // Removed mock tasks

  // NEW: Medications List
  List<Medication> _medications = [];

  // NEW: Emergency Alerts List
  List<EmergencyAlert> _emergencyAlerts = [];
  List<CareRequest> _pendingRequests = [];

  DashboardStats _dashboardStats = DashboardStats(
    totalPatients: 0,
    criticalPatients: 0,
    medicationsGiven: 0,
    pendingTasks: 0,
    completionRate: 0.0,
    dailyActivity: [],
  );

  Map<String, List<ChatMessage>> _chatHistory = {};

  Future<void> fetchDashboardData() async {
    isLoading = true;
    notifyListeners();

    try {
      final email = await const AuthStorageService().getEmail();
      if (email != null) {
        _companionName = email.split('@')[0];
      }

      final patientsRes = await NurseService.getMyPatients();
      if (patientsRes['success']) {
        final List patientsData = patientsRes['patients'] ?? [];
        _patients = patientsData.map((e) => PatientSummary.fromJson(e)).toList();
        _totalPatients = _patients.length;
      }

      final tasksRes = await TaskService.getTasks();
      if (tasksRes['success']) {
        final tasksData = tasksRes['tasks'] as Map<String, dynamic>? ?? {};
        final List<dynamic> flat = [];
        tasksData.forEach((_, list) {
          if (list is List) flat.addAll(list);
        });
        _tasks = flat.map((e) => TaskItem.fromJson(e)).toList();
      }

      final alertsRes = await NurseService.getActiveAlerts();
      if (alertsRes['success']) {
        final List alertsData = alertsRes['alerts'] ?? [];
        _alerts = alertsData.map((e) => AlertMessage.fromJson(e)).toList();
        _criticalAlerts = _alerts.where((a) => a.type == 'critical').length;
      }

      final requestsRes = await NurseService.getPendingRequests();
      if (requestsRes['success']) {
        final List requestsData = requestsRes['requests'] ?? [];
        _pendingRequests = requestsData.map((e) => CareRequest.fromJson(e)).toList();
        _pendingNotifications = _pendingRequests.length;
      }

    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des données: $e");
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      final res = await NurseService.respondToRequest(requestId, action: 'accept');
      if (res['success']) {
        _pendingRequests.removeWhere((req) => req.id == requestId);
        _pendingNotifications = _pendingRequests.length;
        await fetchDashboardData(); // Refresh patients list
      }
    } catch (e) {
      if (kDebugMode) print("Error accepting request: $e");
    }
  }

  Future<void> refuseRequest(String requestId) async {
    try {
      final res = await NurseService.respondToRequest(requestId, action: 'refuse');
      if (res['success']) {
        _pendingRequests.removeWhere((req) => req.id == requestId);
        _pendingNotifications = _pendingRequests.length;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print("Error refusing request: $e");
    }
  }

  String get companionName => _companionName;
  int get pendingNotifications => _pendingNotifications;
  int get totalPatients => _totalPatients;
  int get pendingMedications => _pendingMedications;
  int get criticalAlerts => _criticalAlerts;
  List<PatientSummary> get patients => _patients;
  List<AlertMessage> get alerts => _alerts;
  List<CareRequest> get pendingRequests => _pendingRequests;

  // NEW: Medications Management
  List<Medication> get medications => _medications;

  List<Medication> get pendingMedicationsList =>
      _medications.where((m) => !m.isGiven).toList();

  List<Medication> get givenMedications =>
      _medications.where((m) => m.isGiven).toList();

  void giveMedication(String medicationId) {
    final index = _medications.indexWhere((m) => m.id == medicationId);
    if (index != -1) {
      _medications[index] = Medication(
        id: _medications[index].id,
        patientId: _medications[index].patientId,
        patientName: _medications[index].patientName,
        name: _medications[index].name,
        dosage: _medications[index].dosage,
        frequency: _medications[index].frequency,
        instructions: _medications[index].instructions,
        scheduledTime: _medications[index].scheduledTime,
        isGiven: true,
        givenAt: DateTime.now(),
        notes: _medications[index].notes,
      );
      notifyListeners();
    }
  }

  // NEW: Emergency Alerts Management
  List<EmergencyAlert> get emergencyAlerts => _emergencyAlerts;

  List<EmergencyAlert> get unresolvedEmergencies =>
      _emergencyAlerts.where((e) => !e.isResolved).toList();

  List<EmergencyAlert> get resolvedEmergencies =>
      _emergencyAlerts.where((e) => e.isResolved).toList();

  void resolveEmergency(String alertId, String actionTaken) {
    final index = _emergencyAlerts.indexWhere((e) => e.id == alertId);
    if (index != -1) {
      _emergencyAlerts[index] = EmergencyAlert(
        id: _emergencyAlerts[index].id,
        patientId: _emergencyAlerts[index].patientId,
        patientName: _emergencyAlerts[index].patientName,
        type: _emergencyAlerts[index].type,
        title: _emergencyAlerts[index].title,
        description: _emergencyAlerts[index].description,
        timestamp: _emergencyAlerts[index].timestamp,
        isResolved: true,
        actionTaken: actionTaken,
      );
      notifyListeners();
    }
  }

  List<ChatMessage> getChatHistory(String patientId) {
    return _chatHistory[patientId] ?? [];
  }

  void sendMessage(String patientId, String content) {
    final message = ChatMessage(
      id: Random().nextInt(10000).toString(),
      senderId: 'companion',
      senderName: _companionName,
      content: content,
      timestamp: DateTime.now(),
      isFromPatient: false,
    );

    if (!_chatHistory.containsKey(patientId)) {
      _chatHistory[patientId] = [];
    }
    _chatHistory[patientId]!.add(message);
    notifyListeners();
  }

  void markAlertAsRead(String alertId) {
    final alertIndex = _alerts.indexWhere((a) => a.id == alertId);
    if (alertIndex != -1) {
      _alerts[alertIndex] = AlertMessage(
        id: _alerts[alertIndex].id,
        patientId: _alerts[alertIndex].patientId,
        patientName: _alerts[alertIndex].patientName,
        type: _alerts[alertIndex].type,
        message: _alerts[alertIndex].message,
        timestamp: _alerts[alertIndex].timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }

  void addCriticalAlert(String patientId, String patientName, String message) {
    final alert = AlertMessage(
      id: Random().nextInt(10000).toString(),
      patientId: patientId,
      patientName: patientName,
      type: 'critical',
      message: message,
      timestamp: DateTime.now(),
    );
    _alerts.insert(0, alert);
    notifyListeners();
  }

  // Tasks Management
  List<TaskItem> get tasks => _tasks;

  List<TaskItem> get pendingTasks =>
      _tasks.where((t) => !t.isCompleted).toList();

  List<TaskItem> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  List<TaskItem> getTasksForPatient(String patientId) {
    return _tasks.where((t) => t.patientId == patientId).toList();
  }

  Future<void> completeTask(String taskId) async {
    final res = await TaskService.completeTask(taskId);
    if (res['success']) {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = TaskItem(
          id: _tasks[index].id,
          patientId: _tasks[index].patientId,
          patientName: _tasks[index].patientName,
          title: _tasks[index].title,
          description: _tasks[index].description,
          scheduledTime: _tasks[index].scheduledTime,
          isCompleted: true,
          type: _tasks[index].type,
          notes: _tasks[index].notes,
        );
        notifyListeners();
      }
    }
  }

  Future<void> addTask({required String patientId, required String patientName, required String title, String? description, required String type, required DateTime scheduledTime, String priority = 'normal'}) async {
    final res = await TaskService.createTask(
      patientId: patientId,
      title: title,
      description: description,
      type: type,
      scheduledTime: scheduledTime,
      priority: priority,
    );
    if (res['success']) {
      final taskData = res['task'] as Map<String, dynamic>?;
      if (taskData != null) {
        final task = TaskItem.fromJson(taskData);
        _tasks.add(task);
        notifyListeners();
      }
    }
  }

  Future<void> deleteTask(String taskId) async {
    final res = await TaskService.deleteTask(taskId);
    if (res['success']) {
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    }
  }

  // Dashboard Stats
  DashboardStats get dashboardStats => _dashboardStats;

  Map<String, dynamic> getPatientStatusCounts() {
    return {
      'stable': _patients.where((p) => p.status == PatientStatus.stable).length,
      'critical': _patients
          .where((p) => p.status == PatientStatus.critical)
          .length,
      'monitoring': _patients
          .where((p) => p.status == PatientStatus.monitoring)
          .length,
    };
  }
}

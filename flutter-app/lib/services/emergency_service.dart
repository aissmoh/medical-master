import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage_service.dart';

class Emergency {
  final String id;
  final String patientId;
  final Map<String, dynamic> patient;
  final Map<String, dynamic> location;
  final String type;
  final String? description;
  final String status;
  final Map<String, dynamic>? vitalSigns;
  final String? assignedNurseId;
  final Map<String, dynamic>? assignedNurse;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final double? distance;

  Emergency({
    required this.id,
    required this.patientId,
    required this.patient,
    required this.location,
    required this.type,
    this.description,
    required this.status,
    this.vitalSigns,
    this.assignedNurseId,
    this.assignedNurse,
    required this.createdAt,
    this.resolvedAt,
    this.distance,
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      patientId: (json['patientId'] is Map<String, dynamic>)
          ? json['patientId']['_id']?.toString() ?? ''
          : json['patientId']?.toString() ?? '',
      patient: json['patientId'] is Map<String, dynamic>
          ? json['patientId'] as Map<String, dynamic>
          : {},
      location: json['location'] is Map<String, dynamic>
          ? json['location'] as Map<String, dynamic>
          : {'lat': 0.0, 'lng': 0.0},
      type: json['type']?.toString() ?? 'other',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      vitalSigns: json['vitalSigns'] is Map<String, dynamic>
          ? json['vitalSigns'] as Map<String, dynamic>
          : null,
      assignedNurseId: json['assignedNurseId']?.toString(),
      assignedNurse: json['assignedNurseId'] is Map<String, dynamic>
          ? json['assignedNurseId'] as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'].toString())
          : null,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }
}

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  Future<String?> _getToken() async {
    final authStorage = AuthStorageService();
    return await authStorage.getToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 🚨 Déclencher une urgence (SOS)
  Future<Emergency> triggerEmergency({
    required double lat,
    required double lng,
    String? address,
    String type = 'other',
    String? description,
    Map<String, dynamic>? vitalSigns,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
        'type': type,
        if (description != null) 'description': description,
        if (vitalSigns != null) 'vitalSigns': vitalSigns,
      });

      print('DEBUG: Triggering emergency at: $lat, $lng');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergency/trigger'),
        headers: headers,
        body: body,
      );

      print('DEBUG: Emergency response status: ${response.statusCode}');
      print('DEBUG: Emergency response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Emergency.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception(
        'Failed to trigger emergency - Status: ${response.statusCode}, Body: ${response.body}',
      );
    } catch (e) {
      print('DEBUG: Exception in triggerEmergency: $e');
      throw Exception('Error triggering emergency: $e');
    }
  }

  // 📍 Récupérer les urgences actives (pour les infirmiers)
  Future<List<Emergency>> getActiveEmergencies({
    double? lat,
    double? lng,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final queryParams = <String, String>{};
      if (lat != null) queryParams['lat'] = lat.toString();
      if (lng != null) queryParams['lng'] = lng.toString();

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/emergency/active',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final emergencies = data['data'] as List;
          return emergencies
              .map((json) => Emergency.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw Exception('Failed to load active emergencies: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getActiveEmergencies: $e');
      throw Exception('Error loading active emergencies: $e');
    }
  }

  // 📋 Récupérer mes urgences (Patient)
  Future<List<Emergency>> getPatientEmergencies() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/emergency/patient');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final emergencies = data['data'] as List;
          return emergencies
              .map((json) => Emergency.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw Exception('Failed to load patient emergencies: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getPatientEmergencies: $e');
      throw Exception('Error loading patient emergencies: $e');
    }
  }

  // ✅ Accepter une urgence (Infirmier)
  Future<Emergency> acceptEmergency(String emergencyId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/emergency/$emergencyId/accept');

      final response = await http.patch(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Emergency.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception('Failed to accept emergency: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in acceptEmergency: $e');
      throw Exception('Error accepting emergency: $e');
    }
  }

  // 🚑 Marquer en cours
  Future<Emergency> markInProgress(String emergencyId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/emergency/$emergencyId/in-progress');

      final response = await http.patch(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Emergency.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception('Failed to mark in progress: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in markInProgress: $e');
      throw Exception('Error marking in progress: $e');
    }
  }

  // ✓ Résoudre l'urgence
  Future<Emergency> resolveEmergency(String emergencyId, {String? notes}) async {
    try {
      final headers = await _getHeaders();
      final body = notes != null ? json.encode({'notes': notes}) : null;

      final uri = Uri.parse('${ApiConfig.baseUrl}/emergency/$emergencyId/resolve');

      final response = await http.patch(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Emergency.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception('Failed to resolve emergency: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in resolveEmergency: $e');
      throw Exception('Error resolving emergency: $e');
    }
  }

  // ❌ Annuler l'urgence
  Future<void> cancelEmergency(String emergencyId, {String? reason}) async {
    try {
      final headers = await _getHeaders();
      final body = reason != null ? json.encode({'reason': reason}) : null;

      final uri = Uri.parse('${ApiConfig.baseUrl}/emergency/$emergencyId/cancel');

      final response = await http.patch(
        uri,
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel emergency: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in cancelEmergency: $e');
      throw Exception('Error cancelling emergency: $e');
    }
  }

  // Vérifier s'il y a une urgence active
  Future<Emergency?> getActiveEmergency() async {
    try {
      final emergencies = await getPatientEmergencies();
      final active = emergencies.where((e) => 
        ['pending', 'accepted', 'in_progress'].contains(e.status)
      ).toList();
      
      if (active.isNotEmpty) {
        return active.first;
      }
      return null;
    } catch (e) {
      print('DEBUG: Exception in getActiveEmergency: $e');
      return null;
    }
  }
}

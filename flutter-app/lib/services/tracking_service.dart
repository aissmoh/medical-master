import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';
import 'api_config.dart';
import '../models/tracking_session.dart';

class TrackingService {
  static final _apiUrl = '${ApiConfig.baseUrl}/nurse/tracking';

  static Future<Map<String, dynamic>> _makeRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await const AuthStorageService().getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_apiUrl$endpoint');
      http.Response response;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      switch (method) {
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'GET':
        default:
          response = await http.get(uri, headers: headers);
          break;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, ...data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur serveur',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMyTrackings() async {
    return _makeRequest('s');
  }

  static Future<Map<String, dynamic>> getActiveTracking(String patientId) async {
    return _makeRequest('/$patientId');
  }

  static Future<Map<String, dynamic>> getTrackingHistory(String patientId) async {
    return _makeRequest('/$patientId/history');
  }

  static Future<Map<String, dynamic>> startTracking(
    String patientId, {
    String? initialNotes,
    String? followUpPlan,
  }) async {
    return _makeRequest(
      '/$patientId/start',
      method: 'POST',
      body: {
        if (initialNotes != null) 'initialNotes': initialNotes,
        if (followUpPlan != null) 'followUpPlan': followUpPlan,
      },
    );
  }

  static Future<Map<String, dynamic>> updateStatus(
    String trackingId,
    TrackingStatus status,
  ) async {
    return _makeRequest(
      '/$trackingId/status',
      method: 'PATCH',
      body: {'status': status.toApiValue()},
    );
  }

  static Future<Map<String, dynamic>> addObservation(
    String trackingId,
    Observation observation,
  ) async {
    return _makeRequest(
      '/$trackingId/observation',
      method: 'POST',
      body: observation.toJson(),
    );
  }

  static Future<Map<String, dynamic>> addMedication(
    String trackingId,
    MedicationGiven medication,
  ) async {
    return _makeRequest(
      '/$trackingId/medication',
      method: 'POST',
      body: medication.toJson(),
    );
  }

  static Future<Map<String, dynamic>> completeTracking(
    String trackingId, {
    required String completionNote,
  }) async {
    return _makeRequest(
      '/$trackingId/complete',
      method: 'PATCH',
      body: {'completionNote': completionNote},
    );
  }

  static Future<Map<String, dynamic>> getTrackingStats() async {
    return _makeRequest('/stats');
  }
}

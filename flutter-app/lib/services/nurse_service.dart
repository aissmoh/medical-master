import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';
import 'api_config.dart';

class NurseService {
  static final _apiUrl = '${ApiConfig.baseUrl}/nurse';

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
        case 'PUT':
          response = await http.put(
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
    } on SocketException {
      return {'success': false, 'message': 'Pas de connexion internet'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Get all patients assigned to logged in nurse
  static Future<Map<String, dynamic>> getMyPatients() async {
    return _makeRequest('/my-patients');
  }

  // Get tasks for logged in nurse
  static Future<Map<String, dynamic>> getTasks({String? status}) async {
    final queryParams = status != null ? '?status=$status' : '';
    return _makeRequest('/tasks$queryParams');
  }

  // Complete a task
  static Future<Map<String, dynamic>> completeTask(
    String taskId, {
    String? notes,
  }) async {
    return _makeRequest(
      '/tasks/$taskId/complete',
      method: 'PUT',
      body: notes != null ? {'notes': notes} : null,
    );
  }

  // Get active alerts for nurse
  static Future<Map<String, dynamic>> getAlerts({String? status}) async {
    final queryParams = status != null ? '?status=$status' : '';
    return _makeRequest('/alerts$queryParams');
  }

  // Acknowledge alert (mark as being handled)
  static Future<Map<String, dynamic>> acknowledgeAlert(String alertId) async {
    return _makeRequest('/alerts/$alertId/acknowledge', method: 'PUT');
  }

  // Resolve alert (mark as resolved)
  static Future<Map<String, dynamic>> resolveAlert(
    String alertId, {
    String? notes,
  }) async {
    return _makeRequest(
      '/alerts/$alertId/resolve',
      method: 'PUT',
      body: notes != null ? {'notes': notes} : null,
    );
  }



  // Get detailed info for a specific patient
  static Future<Map<String, dynamic>> getPatientDetails(
    String patientId,
  ) async {
    return _makeRequest('/patient/$patientId/details');
  }

  // Get patient vital signs chart data
  static Future<Map<String, dynamic>> getPatientVitalsChart(
    String patientId, {
    int days = 7,
  }) async {
    return _makeRequest('/patient/$patientId/vitals/chart?days=$days');
  }

  // Get active SOS alerts for nurse
  static Future<Map<String, dynamic>> getActiveAlerts() async {
    return _makeRequest('/alerts');
  }

  // Get alert history for nurse
  static Future<Map<String, dynamic>> getAlertHistory({
    String? status,
    String? patientId,
    int limit = 20,
  }) async {
    String query = '?limit=$limit';
    if (status != null) query += '&status=$status';
    if (patientId != null) query += '&patientId=$patientId';
    return _makeRequest('/alerts/history$query');
  }

  // Create SOS alert (patient only)
  static Future<Map<String, dynamic>> createSOSAlert({
    String? message,
    Map<String, dynamic>? location,
  }) async {
    return _makeRequest(
      '/sos',
      method: 'POST',
      body: {
        if (message != null) 'message': message,
        if (location != null) 'location': location,
      },
    );
  }

  // Get pending care requests from patients
  static Future<Map<String, dynamic>> getPendingRequests() async {
    return _makeRequest('/pending-requests');
  }

  // Accept or refuse a care request
  static Future<Map<String, dynamic>> respondToRequest(
    String requestId, {
    required String action, // "accept" or "refuse"
  }) async {
    return _makeRequest(
      '/respond-request/$requestId',
      method: 'PATCH',
      body: {'action': action},
    );
  }
}

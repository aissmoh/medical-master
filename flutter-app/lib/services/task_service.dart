import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';
import 'api_config.dart';

class TaskService {
  static final _apiUrl = '${ApiConfig.baseUrl}/tasks';

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
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
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

  // Get all tasks for logged in nurse
  static Future<Map<String, dynamic>> getTasks({String? status}) async {
    final queryParams = status != null ? '?status=$status' : '';
    return _makeRequest(queryParams);
  }

  // Get today's task statistics
  static Future<Map<String, dynamic>> getTodayStats() async {
    return _makeRequest('/today/stats');
  }

  // Get tasks for a specific patient
  static Future<Map<String, dynamic>> getPatientTasks(String patientId) async {
    return _makeRequest('/patient/$patientId');
  }

  // Create new task
  static Future<Map<String, dynamic>> createTask({
    required String patientId,
    required String title,
    String? description,
    required String type,
    required DateTime scheduledTime,
    String priority = 'normal',
  }) async {
    return _makeRequest(
      '',
      method: 'POST',
      body: {
        'patientId': patientId,
        'title': title,
        'description': description,
        'type': type,
        'scheduledTime': scheduledTime.toIso8601String(),
        'priority': priority,
      },
    );
  }

  // Complete a task
  static Future<Map<String, dynamic>> completeTask(
    String taskId, {
    String? notes,
  }) async {
    return _makeRequest(
      '/$taskId/complete',
      method: 'PUT',
      body: notes != null ? {'notes': notes} : null,
    );
  }

  // Update task
  static Future<Map<String, dynamic>> updateTask(
    String taskId, {
    Map<String, dynamic>? updates,
  }) async {
    return _makeRequest('/$taskId', method: 'PUT', body: updates);
  }

  // Delete task
  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    return _makeRequest('/$taskId', method: 'DELETE');
  }
}

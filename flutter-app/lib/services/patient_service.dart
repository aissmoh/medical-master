import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';
import 'api_config.dart';

class PatientService {
  static final _apiUrl = '${ApiConfig.baseUrl}/patient';

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

      final uri = endpoint.startsWith('http')
          ? Uri.parse(endpoint)
          : Uri.parse('$_apiUrl$endpoint');
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
      return {
        'success': false,
        'message': 'Pas de connexion internet',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Create emergency SOS alert
  static Future<Map<String, dynamic>> createEmergencyAlert({
    String? message,
    String type = "emergency",
    Map<String, dynamic>? location,
  }) async {
    return _makeRequest(
      '/sos',
      method: 'POST',
      body: {
        'message': message,
        'type': type,
        'location': location,
      },
    );
  }

  // Get patient's alert history
  static Future<Map<String, dynamic>> getMyAlerts() async {
    return _makeRequest('/alerts');
  }

  // Cancel patient's alert
  static Future<Map<String, dynamic>> cancelAlert(String alertId) async {
    return _makeRequest(
      '/alerts/$alertId/cancel',
      method: 'PUT',
    );
  }

  // Get patient's assigned nurse
  static Future<Map<String, dynamic>> getMyNurse() async {
    return _makeRequest('/my-nurse');
  }

  // Get patient's care requests
  static Future<Map<String, dynamic>> getMyRequests() async {
    return _makeRequest('/my-requests');
  }

  // Get all available nurses (Garde Malades)
  static Future<Map<String, dynamic>> getAvailableNurses() async {
    return _makeRequest('/users/nurses');
  }

  // Send alert to assigned nurse with GPS location
  static Future<Map<String, dynamic>> alertMyNurse({
    required double lat,
    required double lng,
    String? message,
  }) async {
    return _makeRequest('/alert-my-nurse', method: 'POST', body: {
      'lat': lat,
      'lng': lng,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  // Send a care request to a garde malade (by email or phone)
  static Future<Map<String, dynamic>> sendCareRequest({
    String? email,
    String? phone,
    String? reason,
    String? urgency,
    List<String>? symptoms,
    double? lat,
    double? lng,
    String? address,
    String? preferredContactTime,
    String? patientNotes,
  }) async {
    final body = <String, dynamic>{};
    if (email != null && email.isNotEmpty) body['email'] = email.trim().toLowerCase();
    if (phone != null && phone.isNotEmpty) body['phone'] = phone.trim();
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    if (urgency != null && urgency.isNotEmpty) body['urgency'] = urgency;
    if (symptoms != null && symptoms.isNotEmpty) body['symptoms'] = symptoms;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    if (address != null && address.isNotEmpty) body['address'] = address;
    if (preferredContactTime != null && preferredContactTime.isNotEmpty) {
      body['preferredContactTime'] = preferredContactTime;
    }
    if (patientNotes != null && patientNotes.isNotEmpty) {
      body['patientNotes'] = patientNotes;
    }

    return _makeRequest(
      '/request-nurse',
      method: 'POST',
      body: body,
    );
  }

  // Send current GPS location to backend independently
  static Future<Map<String, dynamic>> sendMyLocation({
    required double lat,
    required double lng,
    String? address,
  }) async {
    return _makeRequest('/location', method: 'PUT', body: {
      'lat': lat,
      'lng': lng,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  }

  // Get patient profile
  static Future<Map<String, dynamic>> getProfile() async {
    return _makeRequest('${ApiConfig.baseUrl}/users/me');
  }

  // Update patient profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? groupeSanguin,
    String? address,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (groupeSanguin != null) body['groupeSanguin'] = groupeSanguin;
    if (address != null) body['address'] = address;
    return _makeRequest('${ApiConfig.baseUrl}/users/profile', method: 'PUT', body: body);
  }

  // Upload profile photo
  static Future<Map<String, dynamic>> uploadProfilePhoto(String imagePath) async {
    try {
      final token = await const AuthStorageService().getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/users/profile/photo');
      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        imagePath,
        filename: 'profile.jpg',
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, ...data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Erreur serveur'};
      }
    } on SocketException {
      return {'success': false, 'message': 'Pas de connexion internet'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage_service.dart';

class Appointment {
  final String id;
  final String patientId;
  final String? nurseId;
  final DateTime dateTime;
  final int duration;
  final String status;
  final String reason;
  final String? notes;
  final String location;
  final String? rejectionReason;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? nurse;

  Appointment({
    required this.id,
    required this.patientId,
    this.nurseId,
    required this.dateTime,
    required this.duration,
    required this.status,
    required this.reason,
    this.notes,
    required this.location,
    this.rejectionReason,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    required this.createdAt,
    required this.updatedAt,
    this.patient,
    this.nurse,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      patientId: (json['patientId'])?.toString() ?? '',
      nurseId: json['nurseId']?.toString(),
      dateTime: DateTime.parse(json['dateTime'].toString()),
      duration: int.tryParse(json['duration'].toString()) ?? 60,
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      notes: json['notes']?.toString(),
      location: json['location']?.toString() ?? '',
      rejectionReason: json['rejectionReason']?.toString(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'].toString())
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'].toString())
          : null,
      cancelledBy: json['cancelledBy']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      patient: json['patient'] is Map<String, dynamic>
          ? json['patient'] as Map<String, dynamic>?
          : null,
      nurse: json['nurse'] is Map<String, dynamic>
          ? json['nurse'] as Map<String, dynamic>?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'nurseId': nurseId,
      'dateTime': dateTime.toIso8601String(),
      'duration': duration,
      'status': status,
      'reason': reason,
      'notes': notes,
      'location': location,
      'rejectionReason': rejectionReason,
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'patient': patient,
      'nurse': nurse,
    };
  }
}

class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

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

  Future<List<Appointment>> getPatientAppointments({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      print('DEBUG: Headers: $headers');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/appointments/patient',
      ).replace(queryParameters: queryParams);

      print('DEBUG: Request URL: $uri');
      print('DEBUG: Request method: GET');

      final response = await http.get(uri, headers: headers);

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final appointments = data['appointments'] as List;
          print('DEBUG: Parsed ${appointments.length} appointments');
          return appointments
              .map((json) => Appointment.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load appointments');
    } catch (e) {
      print('DEBUG: Exception in getPatientAppointments: $e');
      throw Exception('Error loading appointments: $e');
    }
  }

  Future<List<Appointment>> getNurseAppointments({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/appointments/nurse',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final appointments = data['appointments'] as List;
          return appointments
              .map((json) => Appointment.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load appointments');
    } catch (e) {
      throw Exception('Error loading appointments: $e');
    }
  }

  Future<List<Appointment>> getAvailableAppointments({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/appointments/available',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final appointments = data['appointments'] as List;
          return appointments
              .map((json) => Appointment.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load available appointments');
    } catch (e) {
      throw Exception('Error loading available appointments: $e');
    }
  }

  Future<Appointment> createAppointment({
    required DateTime dateTime,
    required int duration,
    required String reason,
    String? notes,
    required String location,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'dateTime': dateTime.toIso8601String(),
        'duration': duration,
        'reason': reason,
        'notes': notes,
        'location': location,
      });

      print('Creating appointment with body: $body');
      print('Headers: $headers');
      print('URL: ${ApiConfig.baseUrl}/appointments');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/appointments'),
        headers: headers,
        body: body,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Appointment.fromJson(data['appointment']);
        }
      }
      throw Exception(
        'Failed to create appointment - Status: ${response.statusCode}, Body: ${response.body}',
      );
    } catch (e) {
      print('Error in createAppointment: $e');
      throw Exception('Error creating appointment: $e');
    }
  }

  Future<Appointment> acceptAppointment(String appointmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/appointments/$appointmentId/accept'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Appointment.fromJson(data['appointment']);
        }
      }
      throw Exception('Failed to accept appointment');
    } catch (e) {
      throw Exception('Error accepting appointment: $e');
    }
  }

  Future<Appointment> rejectAppointment(
    String appointmentId, {
    String? rejectionReason,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'rejectionReason': rejectionReason});

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/appointments/$appointmentId/reject'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Appointment.fromJson(data['appointment']);
        }
      }
      throw Exception('Failed to reject appointment');
    } catch (e) {
      throw Exception('Error rejecting appointment: $e');
    }
  }

  Future<Appointment> cancelAppointment(
    String appointmentId, {
    String? cancellationReason,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'cancellationReason': cancellationReason});

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/appointments/$appointmentId/cancel'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Appointment.fromJson(data['appointment']);
        }
      }
      throw Exception('Failed to cancel appointment');
    } catch (e) {
      throw Exception('Error cancelling appointment: $e');
    }
  }

  Future<Appointment> completeAppointment(
    String appointmentId, {
    String? completionNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'completionNotes': completionNotes});

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/appointments/$appointmentId/complete'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Appointment.fromJson(data['appointment']);
        }
      }
      throw Exception('Failed to complete appointment');
    } catch (e) {
      throw Exception('Error completing appointment: $e');
    }
  }

  Future<List<Appointment>> getAppointmentsCalendar({
    String view = 'month',
    int? month,
    int? year,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{'view': view};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/appointments/calendar',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final appointments = data['appointments'] as List;
          return appointments
              .map((json) => Appointment.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load calendar appointments');
    } catch (e) {
      throw Exception('Error loading calendar appointments: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage_service.dart';

class VitalSignsReading {
  final String id;
  final String patientId;
  final String? assignedNurseId;
  final VitalMetric? oxygenLevel;
  final VitalMetric? heartRate;
  final VitalMetric? temperature;
  final VitalMetric? vertigo;
  final BloodPressure? bloodPressure;
  final String? notes;
  final DateTime measuredAt;
  final String source;
  final DateTime createdAt;
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? assignedNurse;

  VitalSignsReading({
    required this.id,
    required this.patientId,
    this.assignedNurseId,
    this.oxygenLevel,
    this.heartRate,
    this.temperature,
    this.vertigo,
    this.bloodPressure,
    this.notes,
    required this.measuredAt,
    this.source = 'manual',
    required this.createdAt,
    this.patient,
    this.assignedNurse,
  });

  factory VitalSignsReading.fromJson(Map<String, dynamic> json) {
    return VitalSignsReading(
      id: json['_id'] ?? json['id'] ?? '',
      patientId: json['patientId'] is Map
          ? json['patientId']['_id'] ?? ''
          : json['patientId'] ?? '',
      assignedNurseId: json['assignedNurseId'] is Map
          ? json['assignedNurseId']['_id']
          : json['assignedNurseId'],
      oxygenLevel: json['oxygenLevel'] != null
          ? VitalMetric.fromJson(json['oxygenLevel'])
          : null,
      heartRate: json['heartRate'] != null
          ? VitalMetric.fromJson(json['heartRate'])
          : null,
      temperature: json['temperature'] != null
          ? VitalMetric.fromJson(json['temperature'])
          : null,
      vertigo: json['vertigo'] != null
          ? VitalMetric.fromJson(json['vertigo'])
          : null,
      bloodPressure: json['bloodPressure'] != null
          ? BloodPressure.fromJson(json['bloodPressure'])
          : null,
      notes: json['notes'],
      measuredAt: json['measuredAt'] != null
          ? DateTime.parse(json['measuredAt'])
          : DateTime.now(),
      source: json['source'] ?? 'manual',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      patient: json['patientId'] is Map ? json['patientId'] : null,
      assignedNurse: json['assignedNurseId'] is Map
          ? json['assignedNurseId']
          : null,
    );
  }

  bool get hasCriticalAlert {
    return oxygenLevel?.status == 'critical' ||
        heartRate?.status == 'critical' ||
        temperature?.status == 'critical' ||
        vertigo?.status == 'critical' ||
        bloodPressure?.status == 'critical';
  }

  bool get hasWarningAlert {
    return oxygenLevel?.status == 'warning' ||
        heartRate?.status == 'warning' ||
        temperature?.status == 'warning' ||
        vertigo?.status == 'warning' ||
        bloodPressure?.status == 'warning';
  }

  List<VitalAlert> get alerts {
    final List<VitalAlert> alerts = [];

    if (oxygenLevel?.status == 'critical') {
      alerts.add(
        VitalAlert(
          type: 'Oxygène',
          severity: 'critical',
          message: 'Niveau critique: ${oxygenLevel?.value}%',
          value: oxygenLevel?.value ?? 0,
        ),
      );
    } else if (oxygenLevel?.status == 'warning') {
      alerts.add(
        VitalAlert(
          type: 'Oxygène',
          severity: 'warning',
          message: 'Niveau bas: ${oxygenLevel?.value}%',
          value: oxygenLevel?.value ?? 0,
        ),
      );
    }

    if (heartRate?.status == 'critical') {
      alerts.add(
        VitalAlert(
          type: 'Fréquence Cardiaque',
          severity: 'critical',
          message: 'Anormale: ${heartRate?.value} bpm',
          value: heartRate?.value ?? 0,
        ),
      );
    } else if (heartRate?.status == 'warning') {
      alerts.add(
        VitalAlert(
          type: 'Fréquence Cardiaque',
          severity: 'warning',
          message: '${heartRate?.value} bpm',
          value: heartRate?.value ?? 0,
        ),
      );
    }

    if (temperature?.status == 'critical') {
      alerts.add(
        VitalAlert(
          type: 'Température',
          severity: 'critical',
          message: 'Anormale: ${temperature?.value}°C',
          value: temperature?.value ?? 0,
        ),
      );
    } else if (temperature?.status == 'warning') {
      alerts.add(
        VitalAlert(
          type: 'Température',
          severity: 'warning',
          message: '${temperature?.value}°C',
          value: temperature?.value ?? 0,
        ),
      );
    }

    if (vertigo?.status == 'critical') {
      alerts.add(
        VitalAlert(
          type: 'Vertige',
          severity: 'critical',
          message: 'Critique: ${vertigo?.value} rpm',
          value: vertigo?.value ?? 0,
        ),
      );
    } else if (vertigo?.status == 'warning') {
      alerts.add(
        VitalAlert(
          type: 'Vertige',
          severity: 'warning',
          message: '${vertigo?.value} rpm',
          value: vertigo?.value ?? 0,
        ),
      );
    }

    return alerts;
  }
}

class VitalMetric {
  final double value;
  final String unit;
  final String status;

  VitalMetric({
    required this.value,
    required this.unit,
    this.status = 'normal',
  });

  factory VitalMetric.fromJson(Map<String, dynamic> json) {
    return VitalMetric(
      value: (json['value'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      status: json['status'] ?? 'normal',
    );
  }
}

class BloodPressure {
  final int systolic;
  final int diastolic;
  final String unit;
  final String status;

  BloodPressure({
    required this.systolic,
    required this.diastolic,
    this.unit = 'mmHg',
    this.status = 'normal',
  });

  factory BloodPressure.fromJson(Map<String, dynamic> json) {
    return BloodPressure(
      systolic: json['systolic'] ?? 0,
      diastolic: json['diastolic'] ?? 0,
      unit: json['unit'] ?? 'mmHg',
      status: json['status'] ?? 'normal',
    );
  }
}

class VitalAlert {
  final String type;
  final String severity;
  final String message;
  final double value;

  VitalAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.value,
  });
}

class VitalStats {
  final int totalReadings;
  final int period;
  final MetricStats? oxygenLevel;
  final MetricStats? heartRate;
  final MetricStats? temperature;
  final MetricStats? vertigo;
  final int criticalAlerts;
  final int warningAlerts;

  VitalStats({
    required this.totalReadings,
    required this.period,
    this.oxygenLevel,
    this.heartRate,
    this.temperature,
    this.vertigo,
    required this.criticalAlerts,
    required this.warningAlerts,
  });

  factory VitalStats.fromJson(Map<String, dynamic> json) {
    return VitalStats(
      totalReadings: json['totalReadings'] ?? 0,
      period: json['period'] ?? 7,
      oxygenLevel: json['oxygenLevel'] != null
          ? MetricStats.fromJson(json['oxygenLevel'])
          : null,
      heartRate: json['heartRate'] != null
          ? MetricStats.fromJson(json['heartRate'])
          : null,
      temperature: json['temperature'] != null
          ? MetricStats.fromJson(json['temperature'])
          : null,
      vertigo: json['vertigo'] != null
          ? MetricStats.fromJson(json['vertigo'])
          : null,
      criticalAlerts: json['criticalAlerts'] ?? 0,
      warningAlerts: json['warningAlerts'] ?? 0,
    );
  }
}

class MetricStats {
  final double average;
  final double min;
  final double max;
  final int count;

  MetricStats({
    required this.average,
    required this.min,
    required this.max,
    required this.count,
  });

  factory MetricStats.fromJson(Map<String, dynamic> json) {
    return MetricStats(
      average: (json['average'] ?? 0).toDouble(),
      min: (json['min'] ?? 0).toDouble(),
      max: (json['max'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

class VitalSignsService {
  static Future<Map<String, String>> _getHeaders() async {
    final authStorage = AuthStorageService();
    final token = await authStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 📊 Patient: Record vital signs
  static Future<Map<String, dynamic>> recordVitalSigns({
    double? oxygenLevel,
    double? heartRate,
    double? temperature,
    double? vertigo,
    Map<String, int>? bloodPressure,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (oxygenLevel != null) body['oxygenLevel'] = oxygenLevel;
      if (heartRate != null) body['heartRate'] = heartRate;
      if (temperature != null) body['temperature'] = temperature;
      if (vertigo != null) body['vertigo'] = vertigo;
      if (bloodPressure != null) body['bloodPressure'] = bloodPressure;
      if (notes != null) body['notes'] = notes;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/vitals/record'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('DEBUG: recordVitalSigns - Status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': VitalSignsReading.fromJson(data['data']),
          'alerts': data['alerts'] ?? [],
          'message': data['message'] ?? 'Signes vitaux enregistrés',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de l\'enregistrement',
        };
      }
    } catch (e) {
      print('DEBUG: Exception in recordVitalSigns: $e');
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  // 📊 Patient: Get my latest vital signs
  static Future<VitalSignsReading?> getMyLatestVitalSigns() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vitals/me/latest'),
        headers: headers,
      );

      print('DEBUG: getMyLatestVitalSigns - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VitalSignsReading.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('DEBUG: Exception in getMyLatestVitalSigns: $e');
      return null;
    }
  }

  // 📊 Patient: Get my history
  static Future<List<VitalSignsReading>> getMyVitalSignsHistory({
    int days = 7,
    int limit = 100,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/vitals/me/history?days=$days&limit=$limit',
        ),
        headers: headers,
      );

      print('DEBUG: getMyVitalSignsHistory - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> readings = data['data'] ?? [];
        return readings.map((r) => VitalSignsReading.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      print('DEBUG: Exception in getMyVitalSignsHistory: $e');
      return [];
    }
  }

  // 👨‍⚕️ Nurse: Get all patients vital signs
  static Future<List<Map<String, dynamic>>> getAllPatientsVitalSigns() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vitals/all-patients'),
        headers: headers,
      );

      print('DEBUG: getAllPatientsVitalSigns - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('DEBUG: Exception in getAllPatientsVitalSigns: $e');
      return [];
    }
  }

  // 👨‍⚕️ Nurse: Get alerts
  static Future<List<VitalSignsReading>> getAlerts({
    String? severity,
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();

      var url = '${ApiConfig.baseUrl}/vitals/alerts?limit=$limit';
      if (severity != null) url += '&severity=$severity';

      final response = await http.get(Uri.parse(url), headers: headers);

      print('DEBUG: getAlerts - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> alerts = data['data'] ?? [];
        return alerts.map((a) => VitalSignsReading.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      print('DEBUG: Exception in getAlerts: $e');
      return [];
    }
  }

  // 👨‍⚕️ Nurse: Get patient vital signs
  static Future<VitalSignsReading?> getPatientVitalSigns(
    String patientId,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vitals/patient/$patientId'),
        headers: headers,
      );

      print('DEBUG: getPatientVitalSigns - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VitalSignsReading.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('DEBUG: Exception in getPatientVitalSigns: $e');
      return null;
    }
  }

  // 👨‍⚕️ Nurse: Get patient history
  static Future<List<VitalSignsReading>> getPatientHistory(
    String patientId, {
    int days = 30,
    int limit = 100,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/vitals/patient/$patientId/history?days=$days&limit=$limit',
        ),
        headers: headers,
      );

      print('DEBUG: getPatientHistory - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> readings = data['data'] ?? [];
        return readings.map((r) => VitalSignsReading.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      print('DEBUG: Exception in getPatientHistory: $e');
      return [];
    }
  }

  // 👨‍⚕️ Nurse: Get patient stats
  static Future<VitalStats?> getPatientStats(
    String patientId, {
    int days = 7,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/vitals/patient/$patientId/stats?days=$days',
        ),
        headers: headers,
      );

      print('DEBUG: getPatientStats - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VitalStats.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('DEBUG: Exception in getPatientStats: $e');
      return null;
    }
  }
}

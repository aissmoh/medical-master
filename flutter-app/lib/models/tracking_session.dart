enum TrackingStatus {
  enCours,
  amelioration,
  stable,
  termine;

  String toApiValue() {
    switch (this) {
      case TrackingStatus.enCours:
        return 'en_cours';
      case TrackingStatus.amelioration:
        return 'amélioration';
      case TrackingStatus.stable:
        return 'stable';
      case TrackingStatus.termine:
        return 'terminé';
    }
  }

  static TrackingStatus fromApiValue(String value) {
    switch (value) {
      case 'en_cours':
        return TrackingStatus.enCours;
      case 'amélioration':
        return TrackingStatus.amelioration;
      case 'stable':
        return TrackingStatus.stable;
      case 'terminé':
        return TrackingStatus.termine;
      default:
        return TrackingStatus.enCours;
    }
  }

  String get label {
    switch (this) {
      case TrackingStatus.enCours:
        return 'En cours';
      case TrackingStatus.amelioration:
        return 'Amélioration';
      case TrackingStatus.stable:
        return 'Stable';
      case TrackingStatus.termine:
        return 'Terminé';
    }
  }
}

enum ObservationType {
  subjective,
  objective,
  assessment,
  plan;

  String get label {
    switch (this) {
      case ObservationType.subjective:
        return 'Subjectif (S)';
      case ObservationType.objective:
        return 'Objectif (O)';
      case ObservationType.assessment:
        return 'Assessment (A)';
      case ObservationType.plan:
        return 'Plan (P)';
    }
  }

  String get shortLabel {
    switch (this) {
      case ObservationType.subjective:
        return 'S';
      case ObservationType.objective:
        return 'O';
      case ObservationType.assessment:
        return 'A';
      case ObservationType.plan:
        return 'P';
    }
  }

  String toApiValue() {
    switch (this) {
      case ObservationType.subjective:
        return 'subjective';
      case ObservationType.objective:
        return 'objective';
      case ObservationType.assessment:
        return 'assessment';
      case ObservationType.plan:
        return 'plan';
    }
  }

  static ObservationType fromApiValue(String value) {
    switch (value) {
      case 'subjective':
        return ObservationType.subjective;
      case 'objective':
        return ObservationType.objective;
      case 'assessment':
        return ObservationType.assessment;
      case 'plan':
        return ObservationType.plan;
      default:
        return ObservationType.subjective;
    }
  }
}

class Observation {
  final ObservationType type;
  final String content;
  final String? templateUsed;
  final DateTime recordedAt;

  Observation({
    required this.type,
    required this.content,
    this.templateUsed,
    required this.recordedAt,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      type: ObservationType.fromApiValue(json['type']?.toString() ?? 'subjective'),
      content: json['content']?.toString() ?? '',
      templateUsed: json['templateUsed']?.toString(),
      recordedAt: json['recordedAt'] != null
          ? DateTime.parse(json['recordedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toApiValue(),
      'content': content,
      if (templateUsed != null) 'templateUsed': templateUsed,
    };
  }
}

class MedicationGiven {
  final String name;
  final String dosage;
  final DateTime givenAt;
  final String? notes;

  MedicationGiven({
    required this.name,
    required this.dosage,
    required this.givenAt,
    this.notes,
  });

  factory MedicationGiven.fromJson(Map<String, dynamic> json) {
    return MedicationGiven(
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      givenAt: json['givenAt'] != null
          ? DateTime.parse(json['givenAt'])
          : DateTime.now(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      if (notes != null) 'notes': notes,
    };
  }
}

class VitalSnapshot {
  final double? heartRate;
  final double? temperature;
  final double? oxygenLevel;
  final int? systolicBP;
  final int? diastolicBP;

  const VitalSnapshot({
    this.heartRate,
    this.temperature,
    this.oxygenLevel,
    this.systolicBP,
    this.diastolicBP,
  });

  factory VitalSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VitalSnapshot();
    return VitalSnapshot(
      heartRate: json['heartRate']?['value']?.toDouble(),
      temperature: json['temperature']?['value']?.toDouble(),
      oxygenLevel: json['oxygenLevel']?['value']?.toDouble(),
      systolicBP: json['bloodPressure']?['systolic'] as int?,
      diastolicBP: json['bloodPressure']?['diastolic'] as int?,
    );
  }
}

class TrackingSession {
  final String id;
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? patientBloodGroup;
  TrackingStatus status;
  VitalSnapshot vitalSnapshot;
  List<Observation> observations;
  List<MedicationGiven> medicationsGiven;
  String? notes;
  String? followUpPlan;
  String? completionNote;
  final DateTime createdAt;
  DateTime? completedAt;

  TrackingSession({
    required this.id,
    required this.patientId,
    this.patientName,
    this.patientPhone,
    this.patientBloodGroup,
    required this.status,
    this.vitalSnapshot = const VitalSnapshot(),
    this.observations = const [],
    this.medicationsGiven = const [],
    this.notes,
    this.followUpPlan,
    this.completionNote,
    required this.createdAt,
    this.completedAt,
  });

  Duration get duration {
    final end = completedAt ?? DateTime.now();
    return end.difference(createdAt);
  }

  String get durationLabel {
    final d = duration;
    if (d.inDays > 0) return '${d.inDays}j ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    if (d.inMinutes > 0) return '${d.inMinutes}min';
    return '${d.inSeconds}s';
  }

  factory TrackingSession.fromJson(Map<String, dynamic> json) {
    final patient = json['patientId'] is Map ? json['patientId'] : null;
    return TrackingSession(
      id: json['_id']?.toString() ?? '',
      patientId: patient != null
          ? patient['_id']?.toString() ?? ''
          : json['patientId']?.toString() ?? '',
      patientName: patient?['name']?.toString(),
      patientPhone: patient?['phone']?.toString(),
      patientBloodGroup: patient?['groupeSanguin']?.toString(),
      status: TrackingStatus.fromApiValue(json['status']?.toString() ?? 'en_cours'),
      vitalSnapshot: VitalSnapshot.fromJson(json['vitalSnapshot'] as Map<String, dynamic>?),
      observations: (json['observations'] as List<dynamic>?)
              ?.map((e) => Observation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      medicationsGiven: (json['medicationsGiven'] as List<dynamic>?)
              ?.map((e) => MedicationGiven.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes']?.toString(),
      followUpPlan: json['followUpPlan']?.toString(),
      completionNote: json['completionNote']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

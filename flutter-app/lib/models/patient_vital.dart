enum VitalType { heart, respiration, temperature }

class PatientVital {
  const PatientVital({
    required this.type,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.referenceRange,
    required this.observation,
    required this.updatedAt,
  });

  final VitalType type;
  final String title;
  final String value;
  final String unit;
  final String status;
  final String referenceRange;
  final String observation;
  final String updatedAt;

  String get formattedValue => '$value $unit';
}

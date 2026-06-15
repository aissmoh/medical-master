class ApiResult {
  const ApiResult({
    required this.success,
    required this.message,
    this.statusCode,
    this.data = const {},
  });

  final bool success;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> data;
}

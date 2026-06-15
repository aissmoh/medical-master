import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _defaultDomain = 'birapp.dpdns.org';
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static const String _portOverride = String.fromEnvironment('API_PORT');

  static bool get useMockData => false;

  static String get host => useMockData
      ? 'mock-server'
      : (_hostOverride.isNotEmpty ? _hostOverride : _defaultDomain);

  static String get port => useMockData
      ? '0000'
      : (_portOverride.isNotEmpty ? _portOverride : '443');

  static String get baseUrl =>
      useMockData ? 'mock://api' : 'https://$host/api/v1';

  static List<String> get candidateHosts {
    if (useMockData) {
      return ['mock-server'];
    }

    if (_hostOverride.isNotEmpty) {
      return [_hostOverride];
    }

    return [_defaultDomain];
  }

  static List<Uri> authRouteCandidates(String path) {
    if (useMockData) {
      return [Uri.parse('mock://api/v1$path')];
    }

    return candidateHosts
        .map(
          (candidateHost) =>
              Uri.parse('https://$candidateHost/api/v1$path'),
        )
        .toList();
  }

  static Uri get signupUri => Uri.parse('$baseUrl/auth/signup');

  static Uri get verifySignupOtpUri =>
      Uri.parse('$baseUrl/auth/verify-signup-otp');

  static Uri get loginUri => Uri.parse('$baseUrl/auth/login');
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_result.dart';
import 'api_config.dart';

class AuthService {
  const AuthService();

  Future<ApiResult> signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String phone,
    required bool isPatient,
    String? groupeSanguin,
  }) {
    return _post(
      ApiConfig.authRouteCandidates('/auth/signup'),
      body: {
        'name': name,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        'phone': phone,
        'isPatient': isPatient,
        if (groupeSanguin != null) 'groupeSanguin': groupeSanguin,
      },
    );
  }

  Future<ApiResult> verifySignupOtp({
    required String email,
    required String otp,
  }) {
    return _post(
      ApiConfig.authRouteCandidates('/auth/verify-signup-otp'),
      body: {'email': email, 'otp': otp},
    );
  }

  Future<ApiResult> login({required String email, required String password}) {
    return _post(
      ApiConfig.authRouteCandidates('/auth/login'),
      body: {'email': email, 'password': password},
    );
  }

  Future<ApiResult> logout({required String token}) {
    return _postWithAuth(
      ApiConfig.authRouteCandidates('/auth/logout'),
      token: token,
    );
  }

  Future<ApiResult> _post(
    List<Uri> candidateUris, {
    required Map<String, dynamic> body,
  }) async {
    // Return mock data if enabled
    if (ApiConfig.useMockData) {
      return _getMockResponse(body);
    }

    Object? lastError;

    for (final uri in candidateUris) {
      try {
        _logRequest(uri, body);

        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));

        final json = _decodeBody(response.body);
        final success =
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            json['success'] == true;

        _logResponse(uri, response.statusCode, json);

        return ApiResult(
          success: success,
          message: _extractMessage(json, response.statusCode),
          statusCode: response.statusCode,
          data: {...json, 'requestUrl': uri.toString()},
        );
      } on TimeoutException catch (error) {
        lastError = error;
        _logError(uri, error);
      } on SocketException catch (error) {
        lastError = error;
        _logError(uri, error);
      } catch (error) {
        lastError = error;
        _logError(uri, error);
      }
    }

    if (lastError is TimeoutException) {
      return const ApiResult(
        success: false,
        message: 'La requete a expire. Veuillez reessayer.',
      );
    }

    if (lastError is SocketException) {
      return ApiResult(
        success: false,
        message: _buildNetworkErrorMessage(lastError, candidateUris),
      );
    }

    return ApiResult(
      success: false,
      message:
          'Impossible de contacter le serveur pour le moment. URLs testees: ${candidateUris.map((uri) => uri.host).join(', ')}',
    );
  }

  Future<ApiResult> _postWithAuth(
    List<Uri> candidateUris, {
    required String token,
    Map<String, dynamic>? body,
  }) async {
    // Return mock success if mock data is enabled
    if (ApiConfig.useMockData) {
      return const ApiResult(success: true, message: 'Deconnexion reussie');
    }

    Object? lastError;

    for (final uri in candidateUris) {
      try {
        _logRequest(uri, body ?? {});

        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 15));

        final json = _decodeBody(response.body);
        final success =
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            json['success'] == true;

        _logResponse(uri, response.statusCode, json);

        return ApiResult(
          success: success,
          message: _extractMessage(json, response.statusCode),
          statusCode: response.statusCode,
          data: {...json, 'requestUrl': uri.toString()},
        );
      } on TimeoutException catch (error) {
        lastError = error;
        _logError(uri, error);
      } on SocketException catch (error) {
        lastError = error;
        _logError(uri, error);
      } catch (error) {
        lastError = error;
        _logError(uri, error);
      }
    }

    if (lastError is TimeoutException) {
      return const ApiResult(
        success: false,
        message: 'La requete a expire. Veuillez reessayer.',
      );
    }

    if (lastError is SocketException) {
      return ApiResult(
        success: false,
        message: _buildNetworkErrorMessage(lastError, candidateUris),
      );
    }

    return ApiResult(
      success: false,
      message:
          'Impossible de contacter le serveur pour le moment. URLs testees: ${candidateUris.map((uri) => uri.host).join(', ')}',
    );
  }

  ApiResult _getMockResponse(Map<String, dynamic> body) {
    // Simulate successful login for demo
    if (body.containsKey('email') && body.containsKey('password')) {
      final email = body['email'].toString().toLowerCase();
      // Check if email indicates companion role
      final isPatient =
          !email.contains('companion') &&
          !email.contains('nurse') &&
          !email.contains('soignant');

      return ApiResult(
        success: true,
        message: 'Connexion réussie',
        data: {
          'success': true,
          'message': 'Login successful',
          'user': {
            'id': 1,
            'name': isPatient ? 'Kristian Loup' : 'Sofia Martinez',
            'email': email,
            'isPatient': isPatient,
          },
          'token': 'mock-token-12345',
        },
      );
    }

    // Simulate successful signup
    if (body.containsKey('name') && body.containsKey('email')) {
      return ApiResult(
        success: true,
        message: 'Compte créé avec succès',
        data: {
          'success': true,
          'message': 'Account created successfully',
          'user': {
            'id': 1,
            'name': body['name'],
            'email': body['email'],
            'isPatient': body['isPatient'] ?? true,
          },
        },
      );
    }

    // Simulate successful OTP verification
    if (body.containsKey('email') && body.containsKey('otp')) {
      return const ApiResult(
        success: true,
        message: 'Vérification réussie',
        data: {
          'success': true,
          'message': 'OTP verified successfully',
          'token': 'mock-verified-token-12345',
        },
      );
    }

    return const ApiResult(success: false, message: 'Données invalides');
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return const {};
  }

  String _extractMessage(Map<String, dynamic> json, int statusCode) {
    final message = json['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    if (statusCode >= 500) {
      return 'Une erreur serveur est survenue.';
    }

    return 'Une erreur est survenue.';
  }

  void _logRequest(Uri uri, Map<String, dynamic> body) {
    developer.log('POST $uri\nbody=$body', name: 'AuthService');
  }

  void _logResponse(Uri uri, int statusCode, Map<String, dynamic> json) {
    developer.log(
      'Response $statusCode from $uri\nbody=$json',
      name: 'AuthService',
    );
  }

  void _logError(Uri uri, Object error) {
    developer.log(
      'Request failed for $uri\n$error',
      name: 'AuthService',
      error: error,
    );
  }

  String _buildNetworkErrorMessage(
    SocketException error,
    List<Uri> candidateUris,
  ) {
    final baseMessage =
        'Connexion impossible au serveur. Verifiez que le backend est lance, que le telephone/emulateur est sur le meme reseau, et que l\'adresse API est correcte. URLs testees: ${candidateUris.map((uri) => uri.host).join(', ')}.';

    if (kDebugMode && error.message.trim().isNotEmpty) {
      return '$baseMessage (${error.message})';
    }

    return baseMessage;
  }
}

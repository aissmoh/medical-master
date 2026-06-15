import 'package:flutter/material.dart';

import '../models/api_result.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';

class LogoutController {
  LogoutController({
    AuthService? authService,
    AuthStorageService? authStorageService,
  }) : _authService = authService ?? const AuthService(),
       _authStorageService = authStorageService ?? const AuthStorageService();

  final AuthService _authService;
  final AuthStorageService _authStorageService;

  Future<ApiResult> logout() async {
    final token = await _authStorageService.getToken();

    if (token == null || token.isEmpty) {
      // No token, just clear local session
      await _authStorageService.clearSession();
      return const ApiResult(
        success: true,
        message: 'Déconnexion réussie',
      );
    }

    try {
      final result = await _authService.logout(token: token);

      if (result.success) {
        await _authStorageService.clearSession();
      }

      return result;
    } catch (error) {
      // Even if API call fails, clear local session
      await _authStorageService.clearSession();
      return ApiResult(
        success: true,
        message: 'Déconnexion réussie (hors ligne)',
      );
    }
  }
}

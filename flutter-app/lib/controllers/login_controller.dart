import 'package:flutter/material.dart';

import '../models/api_result.dart';
import '../models/login_form_state.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';

class LoginController extends ChangeNotifier {
  LoginController({
    AuthService? authService,
    AuthStorageService? authStorageService,
  }) : _authService = authService ?? const AuthService(),
       _authStorageService = authStorageService ?? const AuthStorageService();

  final AuthService _authService;
  final AuthStorageService _authStorageService;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginFormState _state = const LoginFormState();

  LoginFormState get state => _state;

  String get normalizedEmail => emailController.text.trim().toLowerCase();

  String get normalizedPassword => passwordController.text.trim();

  void toggleRememberMe() {
    _state = _state.copyWith(rememberMe: !_state.rememberMe);
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _state = _state.copyWith(obscurePassword: !_state.obscurePassword);
    notifyListeners();
  }

  bool get hasValidEmail {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail);
  }

  bool get isFormValid {
    return normalizedEmail.isNotEmpty &&
        normalizedPassword.isNotEmpty &&
        hasValidEmail;
  }

  String? validateLoginForm() {
    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      return 'Veuillez remplir l’e-mail et le mot de passe.';
    }

    if (!hasValidEmail) {
      return 'Veuillez saisir une adresse e-mail valide.';
    }

    return null;
  }

  Future<ApiResult> submitLogin() async {
    if (state.isSubmitting) {
      return const ApiResult(
        success: false,
        message: 'La connexion est deja en cours.',
      );
    }

    final validationError = validateLoginForm();
    if (validationError != null) {
      return ApiResult(success: false, message: validationError);
    }

    _setSubmitting(true);

    try {
      final result = await _authService.login(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      if (result.success) {
        final userName = result.data['user']?['name']?.toString() ?? '';
        await _authStorageService.saveSession(
          token: result.data['token']?.toString() ?? '',
          email: normalizedEmail,
          rememberMe: state.rememberMe,
          name: userName.isNotEmpty ? userName : null,
        );
      }

      return result;
    } finally {
      _setSubmitting(false);
    }
  }

  void _setSubmitting(bool value) {
    _state = _state.copyWith(isSubmitting: value);
    notifyListeners();
  }

  void clearFields() {
    emailController.clear();
    passwordController.clear();
    _state = const LoginFormState();
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

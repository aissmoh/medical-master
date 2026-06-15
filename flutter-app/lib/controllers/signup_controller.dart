import 'package:flutter/material.dart';

import '../models/api_result.dart';
import '../models/otp_verification_stage.dart';
import '../models/signup_form_state.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class SignupController extends ChangeNotifier {
  SignupController({AuthService? authService})
    : _authService = authService ?? const AuthService() {
    otpController.addListener(_handleOtpChanged);
  }

  final AuthService _authService;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  SignupFormState _state = const SignupFormState();

  SignupFormState get state => _state;

  String get normalizedName => nameController.text.trim();

  String get normalizedEmail => emailController.text.trim().toLowerCase();

  String get normalizedPassword => passwordController.text.trim();

  String get normalizedConfirmPassword => confirmPasswordController.text.trim();

  String get normalizedPhone => phoneController.text.trim();

  String get normalizedOtp => otpController.text.trim();

  String get maskedPendingEmail {
    final email = state.pendingEmail ?? normalizedEmail;
    if (email.isEmpty || !email.contains('@')) {
      return email;
    }

    final parts = email.split('@');
    final localPart = parts.first;
    final domain = parts.last;

    if (localPart.length <= 2) {
      return '${localPart[0]}***@$domain';
    }

    return '${localPart.substring(0, 2)}***@$domain';
  }

  void togglePasswordVisibility() {
    _state = _state.copyWith(obscurePassword: !_state.obscurePassword);
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _state = _state.copyWith(
      obscureConfirmPassword: !_state.obscureConfirmPassword,
    );
    notifyListeners();
  }

  void selectRole(UserRole role) {
    _state = _state.copyWith(selectedRole: role);
    notifyListeners();
  }

  void selectGroupeSanguin(String groupeSanguin) {
    _state = _state.copyWith(selectedGroupeSanguin: groupeSanguin);
    notifyListeners();
  }

  bool get doPasswordsMatch {
    return normalizedPassword == normalizedConfirmPassword;
  }

  bool get hasValidEmail {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail);
  }

  bool get isFormValid {
    return normalizedName.isNotEmpty &&
        normalizedEmail.isNotEmpty &&
        normalizedPassword.isNotEmpty &&
        normalizedConfirmPassword.isNotEmpty &&
        hasValidEmail &&
        doPasswordsMatch &&
        state.selectedRole != null;
  }

  bool get isOtpValid {
    return RegExp(r'^\d{4}$').hasMatch(normalizedOtp);
  }

  String? validateSignupForm() {
    if (normalizedName.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPhone.isEmpty ||
        normalizedPassword.isEmpty ||
        normalizedConfirmPassword.isEmpty) {
      return 'Veuillez remplir tous les champs du formulaire.';
    }

    if (!hasValidEmail) {
      return 'Veuillez saisir une adresse e-mail valide.';
    }

    if (!RegExp(r'^0[567]\d{8}$').hasMatch(normalizedPhone)) {
      return 'Le numéro de téléphone doit commencer par 05, 06 ou 07 et contenir 10 chiffres.';
    }

    if (state.selectedRole == null) {
      return 'Veuillez selectionner votre role.';
    }

    if (state.selectedRole == UserRole.patient && state.selectedGroupeSanguin == null) {
      return 'Veuillez selectionner votre groupe sanguin.';
    }

    if (!doPasswordsMatch) {
      return 'Les mots de passe ne correspondent pas.';
    }

    if (normalizedPassword.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caracteres.';
    }

    return null;
  }

  String? validateOtp() {
    if (normalizedOtp.isEmpty) {
      return 'Veuillez saisir le code OTP recu par email.';
    }

    if (!isOtpValid) {
      return 'Le code OTP doit contenir exactement 4 chiffres.';
    }

    return null;
  }

  Future<ApiResult> submitSignup() async {
    if (state.isSubmitting) {
      return const ApiResult(
        success: false,
        message: 'La creation du compte est deja en cours.',
      );
    }

    final validationError = validateSignupForm();
    if (validationError != null) {
      return ApiResult(success: false, message: validationError);
    }

    _setSubmitting(true);

    try {
      final result = await _authService.signUp(
        name: normalizedName,
        email: normalizedEmail,
        password: normalizedPassword,
        confirmPassword: normalizedConfirmPassword,
        phone: normalizedPhone,
        isPatient: state.selectedRole == UserRole.patient,
        groupeSanguin: state.selectedRole == UserRole.patient ? state.selectedGroupeSanguin : null,
      );

      if (result.success) {
        _state = _state.copyWith(
          pendingEmail: normalizedEmail,
          otpStage: OtpVerificationStage.input,
          resetOtpFeedbackMessage: true,
        );
        notifyListeners();
      }

      return result;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<ApiResult> verifyOtp() async {
    if (state.isVerifyingOtp) {
      return const ApiResult(
        success: false,
        message: 'La verification du code est deja en cours.',
      );
    }

    final validationError = validateOtp();
    if (validationError != null) {
      return ApiResult(success: false, message: validationError);
    }

    final email = state.pendingEmail ?? normalizedEmail;
    if (email.isEmpty) {
      return const ApiResult(
        success: false,
        message: "Aucun email d'inscription n'a ete detecte.",
      );
    }

    _setVerifyingOtp(true);

    try {
      final result = await _authService.verifySignupOtp(
        email: email,
        otp: normalizedOtp,
      );

      if (result.success) {
        _state = _state.copyWith(
          otpStage: OtpVerificationStage.success,
          otpFeedbackMessage: result.message,
        );
        notifyListeners();
      } else {
        _state = _state.copyWith(
          otpStage: OtpVerificationStage.failure,
          otpFeedbackMessage: result.message,
        );
        notifyListeners();
      }

      return result;
    } finally {
      _setVerifyingOtp(false);
    }
  }

  Future<ApiResult> resendOtp() async {
    if (state.isResendingOtp) {
      return const ApiResult(
        success: false,
        message: "Le renvoi du code est deja en cours.",
      );
    }

    _state = _state.copyWith(isResendingOtp: true);
    notifyListeners();

    try {
      final result = await _authService.signUp(
        name: normalizedName,
        email: state.pendingEmail ?? normalizedEmail,
        password: normalizedPassword,
        confirmPassword: normalizedConfirmPassword,
        phone: normalizedPhone,
        isPatient: state.selectedRole == UserRole.patient,
        groupeSanguin: state.selectedRole == UserRole.patient ? state.selectedGroupeSanguin : null,
      );

      _state = _state.copyWith(
        otpStage: OtpVerificationStage.input,
        otpFeedbackMessage: result.message,
      );
      notifyListeners();

      return result;
    } finally {
      _state = _state.copyWith(isResendingOtp: false);
      notifyListeners();
    }
  }

  void _setSubmitting(bool value) {
    _state = _state.copyWith(isSubmitting: value);
    notifyListeners();
  }

  void _setVerifyingOtp(bool value) {
    _state = _state.copyWith(isVerifyingOtp: value);
    notifyListeners();
  }

  void resetOtpFlow() {
    otpController.clear();
    _state = _state.copyWith(
      otpStage: OtpVerificationStage.input,
      resetOtpFeedbackMessage: true,
    );
    notifyListeners();
  }

  void completeOtpFlow() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    otpController.clear();
    _state = const SignupFormState();
    notifyListeners();
  }

  void _handleOtpChanged() {
    if (state.otpStage != OtpVerificationStage.input) {
      _state = _state.copyWith(
        otpStage: OtpVerificationStage.input,
        resetOtpFeedbackMessage: true,
      );
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.removeListener(_handleOtpChanged);
    otpController.dispose();
    super.dispose();
  }
}

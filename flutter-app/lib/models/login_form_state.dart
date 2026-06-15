class LoginFormState {
  const LoginFormState({
    this.rememberMe = false,
    this.obscurePassword = true,
    this.isSubmitting = false,
  });

  final bool rememberMe;
  final bool obscurePassword;
  final bool isSubmitting;

  LoginFormState copyWith({
    bool? rememberMe,
    bool? obscurePassword,
    bool? isSubmitting,
  }) {
    return LoginFormState(
      rememberMe: rememberMe ?? this.rememberMe,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

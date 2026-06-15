import 'otp_verification_stage.dart';
import 'user_role.dart';

class SignupFormState {
  const SignupFormState({
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.isSubmitting = false,
    this.isVerifyingOtp = false,
    this.isResendingOtp = false,
    this.selectedRole,
    this.pendingEmail,
    this.otpStage = OtpVerificationStage.input,
    this.otpFeedbackMessage,
    this.selectedGroupeSanguin,
  });

  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isSubmitting;
  final bool isVerifyingOtp;
  final bool isResendingOtp;
  final UserRole? selectedRole;
  final String? pendingEmail;
  final OtpVerificationStage otpStage;
  final String? otpFeedbackMessage;
  final String? selectedGroupeSanguin;

  SignupFormState copyWith({
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    bool? isSubmitting,
    bool? isVerifyingOtp,
    bool? isResendingOtp,
    UserRole? selectedRole,
    String? pendingEmail,
    OtpVerificationStage? otpStage,
    String? otpFeedbackMessage,
    String? selectedGroupeSanguin,
    bool resetSelectedRole = false,
    bool resetPendingEmail = false,
    bool resetOtpFeedbackMessage = false,
    bool resetSelectedGroupeSanguin = false,
  }) {
    return SignupFormState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      isResendingOtp: isResendingOtp ?? this.isResendingOtp,
      selectedRole: resetSelectedRole
          ? null
          : selectedRole ?? this.selectedRole,
      pendingEmail: resetPendingEmail
          ? null
          : pendingEmail ?? this.pendingEmail,
      otpStage: otpStage ?? this.otpStage,
      otpFeedbackMessage: resetOtpFeedbackMessage
          ? null
          : otpFeedbackMessage ?? this.otpFeedbackMessage,
      selectedGroupeSanguin: resetSelectedGroupeSanguin
          ? null
          : selectedGroupeSanguin ?? this.selectedGroupeSanguin,
    );
  }
}

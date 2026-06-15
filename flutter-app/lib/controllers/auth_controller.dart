import '../models/user_role.dart';

class AuthController {
  const AuthController(this.role);

  final UserRole role;

  String get roleLabel {
    return role == UserRole.patient ? 'Patient' : 'Garde malade';
  }

  bool get canOpenPatientDashboard {
    return role == UserRole.patient;
  }
}

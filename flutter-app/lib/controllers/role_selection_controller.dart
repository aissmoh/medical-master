import 'package:flutter/material.dart';

import '../models/user_role.dart';

class RoleSelectionController extends ChangeNotifier {
  UserRole? _selectedRole;

  UserRole? get selectedRole => _selectedRole;

  bool get canContinue => _selectedRole != null;

  void selectRole(UserRole role) {
    if (_selectedRole == role) {
      return;
    }
    _selectedRole = role;
    notifyListeners();
  }
}

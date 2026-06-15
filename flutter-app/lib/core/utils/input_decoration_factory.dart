import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'color_utils.dart';

InputDecoration buildInputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIcon: icon == null ? null : Icon(icon, color: Colors.white70),
    filled: true,
    fillColor: withOpacity(Colors.white, 0.08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kAccent),
    ),
  );
}

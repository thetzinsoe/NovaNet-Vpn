import 'package:flutter/material.dart';

/// Enterprise palette: Sea Blue (#006994) and White per project standards.
abstract final class AppColors {
  static const Color seaBlue = Color(0xFF006994);
  static const Color seaBlueDark = Color(0xFF004D6B);
  static const Color seaBlueLight = Color(0xFF3385AD);

  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5FAFC);
  static const Color surface = white;
  static const Color surfaceElevated = Color(0xFFE8F4F8);
  static const Color outlineMuted = Color(0xFFB8D4E0);

  static const Color accent = seaBlue;
  static const Color accentDim = seaBlueDark;
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFFE65100);
  static const Color textPrimary = Color(0xFF1A2B33);
  static const Color textSecondary = Color(0xFF5C7580);
}

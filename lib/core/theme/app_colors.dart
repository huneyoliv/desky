import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme Colors — AMOLED True Black
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0F);
  static const Color surfaceLight = Color(0xFF111118);
  static const Color card = Color(0xFF0D0D14);
  static const Color border = Color(0xFF1E1E2E);

  // Brand Colors — Indigo family extracted from logo
  static const Color primary = Color(0xFF6B8EF0);
  static const Color primaryDark = Color(0xFF2B5EC9);
  static const Color primaryLight = Color(0xFFA4BDFF);

  // Flame / Accent — Lavender from logo + warm streak accents
  static const Color flame = Color(0xFFFF6B6B);
  static const Color flameOrange = Color(0xFFFF9052);
  static const Color accent = Color(0xFFB9A8CC);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0EFFF);
  static const Color textSecondary = Color(0xFF9E9EBB);
  static const Color textMuted = Color(0xFF5C5C7A);

  // Status Colors
  static const Color success = Color(0xFF00E5A0);
  static const Color warning = Color(0xFFFFBE44);
  static const Color error = Color(0xFFFF5370);
  static const Color info = Color(0xFF4FC3F7);

  // Timer & Study States
  static const Color studying = Color(0xFF6B8EF0);
  static const Color resting = Color(0xFFFFBE44);
  static const Color stopped = Color(0xFF5C5C7A);

  // Material 3 Semantic Tokens
  static const Color outline = Color(0xFF383855);
  static const Color lavender = Color(0xFFB9A8CC);
  static const Color accentDark = Color(0xFF7E6A96);

  // Activity Heatmap / Calendar (Lavender Palette)
  static const Color heatmapL1 = Color(0xFF1A1228);
  static const Color heatmapL2 = Color(0xFF2E1F52);
  static const Color heatmapL3 = Color(0xFF5A3D9A);
  static const Color heatmapL4 = Color(0xFFB9A8CC);
}

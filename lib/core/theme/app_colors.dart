import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme Colors — AMOLED True Black
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0F);
  static const Color surfaceLight = Color(0xFF111118);
  static const Color card = Color(0xFF0D0D14);
  static const Color border = Color(0xFF1E1E2E);

  // Brand Colors — Lilac/Lavender from logo background as Primary
  static const Color primary = Color(0xFFA78BFA); // Vibrant Lilac
  static const Color primaryDark = Color(0xFF6D4CA7);
  static const Color primaryLight = Color(0xFFCFD3F0); // Pastel Periwinkle/Lavender from logo

  // Secondary / Accent — Slate Blue from the hourglass facets
  static const Color accent = Color(0xFF6D8DBA);
  static const Color accentDark = Color(0xFF4A6C98);
  static const Color flame = Color(0xFFFF6B6B);
  static const Color flameOrange = Color(0xFFFF9052);

  // Text Colors
  static const Color textPrimary = Color(0xFFF5F3FF); // Subtle lilac-white
  static const Color textSecondary = Color(0xFFA89FBD);
  static const Color textMuted = Color(0xFF685F7D);

  // Status Colors
  static const Color success = Color(0xFF00E5A0);
  static const Color warning = Color(0xFFFFBE44);
  static const Color error = Color(0xFFFF5370);
  static const Color info = Color(0xFF4A7FB5);

  // Timer & Study States
  static const Color studying = Color(0xFFA78BFA);
  static const Color resting = Color(0xFFFFBE44);
  static const Color stopped = Color(0xFF685F7D);

  // Material 3 Semantic Tokens
  static const Color outline = Color(0xFF483960);
  static const Color lavender = Color(0xFFA78BFA);

  // Activity Heatmap / Calendar (Lavender Palette)
  static const Color heatmapL1 = Color(0xFF191225);
  static const Color heatmapL2 = Color(0xFF311F4F);
  static const Color heatmapL3 = Color(0xFF65439C);
  static const Color heatmapL4 = Color(0xFFA78BFA);
}

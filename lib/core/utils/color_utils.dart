import 'package:flutter/material.dart';

class ColorUtils {
  ColorUtils._();

  static const List<int> defaultSubjectColors = [
    // Reds & Corals
    0xFFE53935,
    0xFFF44336,
    0xFFFF5252,
    0xFFFF6B6B,
    0xFFFF7675,
    0xFFE17055,

    // Pinks & Magentas
    0xFFD81B60,
    0xFFE91E63,
    0xFFFF4081,
    0xFFF06292,
    0xFFFD79A8,
    0xFFBA68C8,

    // Purples & Indigos
    0xFF8E24AA,
    0xFF9C27B0,
    0xFF673AB7,
    0xFF7E57C2,
    0xFFA29BFE,
    0xFF5B6AF0,

    // Blues & Cyans
    0xFF1976D2,
    0xFF2196F3,
    0xFF42A5F5,
    0xFF74B9FF,
    0xFF00ACC1,
    0xFF00BCD4,
    0xFF26C6DA,
    0xFF4ECDC4,
    4284513675, // 0xFF5F758B (YPT Slate Default)

    // Greens & Mints
    0xFF2E7D32,
    0xFF4CAF50,
    0xFF81C784,
    0xFF8BC34A,
    0xFF009688,
    0xFF00B894,
    0xFF55EFC4,

    // Yellows, Oranges & Earth tones
    0xFFFFD54F,
    0xFFFFC107,
    0xFFFF9800,
    0xFFFB8C00,
    0xFFFF5722,
    0xFF795548,
    0xFF8D6E63,
    0xFF607D8B,
    0xFF455A64,
  ];

  static Color fromArgbInt(int argb) {
    if (argb == 0) return const Color(0xFF6B8EF0);
    return Color(argb).withValues(alpha: 1.0);
  }

  static int toArgbInt(Color color) {
    return (color.a * 255).toInt() << 24 |
        (color.r * 255).toInt() << 16 |
        (color.g * 255).toInt() << 8 |
        (color.b * 255).toInt();
  }
}

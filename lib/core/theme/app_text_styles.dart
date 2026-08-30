import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontText = 'SF-Pro-Text';
  static const String fontDisplay = 'SF-Pro-Display';
  static const String fontTimer = 'E1234';
  // Backward compatibility alias
  static const String fontPretendard = 'SF-Pro-Text';

  static const List<String> fontFallbacks = ['AppleEmoji', 'Pretendard'];

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontFallbacks,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontFallbacks,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontText,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontText,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontText,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontText,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // Digital Timer font style
  static const TextStyle timerDisplay = TextStyle(
    fontFamily: fontTimer,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 2.0,
  );
}

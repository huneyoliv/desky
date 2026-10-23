import 'package:flutter/material.dart';

class DeskyThemePalette {
  final String id;
  final String nameKey;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color card;
  final Color border;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color accentDark;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color heatmapL1;
  final Color heatmapL2;
  final Color heatmapL3;
  final Color heatmapL4;

  const DeskyThemePalette({
    required this.id,
    required this.nameKey,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.card,
    required this.border,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.accentDark,
    required this.outline,
    this.textPrimary = const Color(0xFFF5F3FF),
    this.textSecondary = const Color(0xFFA89FBD),
    this.textMuted = const Color(0xFF685F7D),
    required this.heatmapL1,
    required this.heatmapL2,
    required this.heatmapL3,
    required this.heatmapL4,
  });

  // 1. AMOLED Lilac (Default Brand Theme)
  static const DeskyThemePalette amoledLilac = DeskyThemePalette(
    id: 'amoled_lilac',
    nameKey: 'theme_amoled_lilac',
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0F),
    surfaceLight: Color(0xFF111118),
    card: Color(0xFF0D0D14),
    border: Color(0xFF1E1E2E),
    primary: Color(0xFFA78BFA),
    primaryDark: Color(0xFF6D4CA7),
    primaryLight: Color(0xFFCFD3F0),
    accent: Color(0xFF6D8DBA),
    accentDark: Color(0xFF4A6C98),
    outline: Color(0xFF483960),
    heatmapL1: Color(0xFF191225),
    heatmapL2: Color(0xFF311F4F),
    heatmapL3: Color(0xFF65439C),
    heatmapL4: Color(0xFFA78BFA),
  );

  // 2. Midnight Navy
  static const DeskyThemePalette midnightNavy = DeskyThemePalette(
    id: 'midnight_navy',
    nameKey: 'theme_midnight_navy',
    background: Color(0xFF070B14),
    surface: Color(0xFF0D1527),
    surfaceLight: Color(0xFF142038),
    card: Color(0xFF0F1A30),
    border: Color(0xFF1E2D4A),
    primary: Color(0xFF38BDF8),
    primaryDark: Color(0xFF0284C7),
    primaryLight: Color(0xFFBAE6FD),
    accent: Color(0xFF60A5FA),
    accentDark: Color(0xFF2563EB),
    outline: Color(0xFF1E3A8A),
    textPrimary: Color(0xFFF0F9FF),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    heatmapL1: Color(0xFF0C1E38),
    heatmapL2: Color(0xFF0369A1),
    heatmapL3: Color(0xFF0284C7),
    heatmapL4: Color(0xFF38BDF8),
  );

  // 3. Cyberpunk Neon
  static const DeskyThemePalette cyberpunk = DeskyThemePalette(
    id: 'cyberpunk',
    nameKey: 'theme_cyberpunk',
    background: Color(0xFF0D0614),
    surface: Color(0xFF170C24),
    surfaceLight: Color(0xFF221235),
    card: Color(0xFF1B0E2B),
    border: Color(0xFF341A52),
    primary: Color(0xFFE879F9),
    primaryDark: Color(0xFFA21CAF),
    primaryLight: Color(0xFFF5D0FE),
    accent: Color(0xFF22D3EE),
    accentDark: Color(0xFF0891B2),
    outline: Color(0xFF581C87),
    textPrimary: Color(0xFFFDF4FF),
    textSecondary: Color(0xFFA78BFA),
    textMuted: Color(0xFF701A75),
    heatmapL1: Color(0xFF260D38),
    heatmapL2: Color(0xFF701A75),
    heatmapL3: Color(0xFFA21CAF),
    heatmapL4: Color(0xFFE879F9),
  );

  // 4. Forest Emerald
  static const DeskyThemePalette forestEmerald = DeskyThemePalette(
    id: 'forest_emerald',
    nameKey: 'theme_forest_emerald',
    background: Color(0xFF06110B),
    surface: Color(0xFF0B1F15),
    surfaceLight: Color(0xFF122C1F),
    card: Color(0xFF0E251A),
    border: Color(0xFF1D4230),
    primary: Color(0xFF34D399),
    primaryDark: Color(0xFF059669),
    primaryLight: Color(0xFFA7F3D0),
    accent: Color(0xFF10B981),
    accentDark: Color(0xFF047857),
    outline: Color(0xFF064E3B),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFF6EE7B7),
    textMuted: Color(0xFF065F46),
    heatmapL1: Color(0xFF092918),
    heatmapL2: Color(0xFF047857),
    heatmapL3: Color(0xFF059669),
    heatmapL4: Color(0xFF34D399),
  );

  // 5. Sunset Amber
  static const DeskyThemePalette sunsetAmber = DeskyThemePalette(
    id: 'sunset_amber',
    nameKey: 'theme_sunset_amber',
    background: Color(0xFF120B06),
    surface: Color(0xFF1E130B),
    surfaceLight: Color(0xFF2C1C11),
    card: Color(0xFF24170E),
    border: Color(0xFF452A18),
    primary: Color(0xFFF59E0B),
    primaryDark: Color(0xFFB45309),
    primaryLight: Color(0xFFFDE68A),
    accent: Color(0xFFFB923C),
    accentDark: Color(0xFFC2410C),
    outline: Color(0xFF78350F),
    textPrimary: Color(0xFFFFFBEB),
    textSecondary: Color(0xFFFCD34D),
    textMuted: Color(0xFF78350F),
    heatmapL1: Color(0xFF2B1705),
    heatmapL2: Color(0xFF92400E),
    heatmapL3: Color(0xFFB45309),
    heatmapL4: Color(0xFFF59E0B),
  );

  static const List<DeskyThemePalette> presets = [
    amoledLilac,
    midnightNavy,
    cyberpunk,
    forestEmerald,
    sunsetAmber,
  ];

  static DeskyThemePalette fromId(String? id) {
    if (id == null) return amoledLilac;
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => amoledLilac,
    );
  }
}

@immutable
class DeskyThemeExtension extends ThemeExtension<DeskyThemeExtension> {
  final DeskyThemePalette palette;

  const DeskyThemeExtension({required this.palette});

  @override
  DeskyThemeExtension copyWith({DeskyThemePalette? palette}) {
    return DeskyThemeExtension(palette: palette ?? this.palette);
  }

  @override
  DeskyThemeExtension lerp(ThemeExtension<DeskyThemeExtension>? other, double t) {
    if (other is! DeskyThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension DeskyThemeContext on BuildContext {
  DeskyThemePalette get palette =>
      Theme.of(this).extension<DeskyThemeExtension>()?.palette ??
      DeskyThemePalette.amoledLilac;
}

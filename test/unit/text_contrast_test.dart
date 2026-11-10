import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/theme/app_colors.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// Minimum ratio for normal-size text under WCAG 2.1 level AA.
const double _aa = 4.5;

List<Color> _surfaces(DeskyThemePalette p) =>
    [p.background, p.surface, p.card, p.surfaceLight];

void main() {
  group('Text contrast (WCAG 2.1 AA)', () {
    test('every theme keeps textMuted readable on every surface', () {
      for (final palette in DeskyThemePalette.presets) {
        for (final surface in _surfaces(palette)) {
          final ratio = _contrast(palette.textMuted, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(_aa),
            reason: '${palette.id}: textMuted precisa de >= $_aa:1 contra a superficie, '
                'mas ficou em ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('every theme keeps textSecondary readable on every surface', () {
      for (final palette in DeskyThemePalette.presets) {
        for (final surface in _surfaces(palette)) {
          final ratio = _contrast(palette.textSecondary, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(_aa),
            reason: '${palette.id}: textSecondary ficou em ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('textMuted stays less prominent than textSecondary', () {
      for (final palette in DeskyThemePalette.presets) {
        final muted = _contrast(palette.textMuted, palette.background);
        final secondary = _contrast(palette.textSecondary, palette.background);
        expect(
          muted,
          lessThan(secondary),
          reason: '${palette.id}: textMuted ($muted) deveria ser menos proeminente '
              'que textSecondary ($secondary)',
        );
      }
    });

    test('the constant textMuted stays compliant on the default palette', () {
      // AppTextStyles uses the constant (a const TextStyle cannot read the theme),
      // so its value must at least be safe on the default AMOLED palette.
      for (final surface in _surfaces(DeskyThemePalette.amoledLilac)) {
        expect(
          _contrast(AppColors.textMuted, surface),
          greaterThanOrEqualTo(_aa),
          reason: 'AppColors.textMuted ficou abaixo de $_aa:1 na paleta padrao',
        );
      }
    });
  });
}

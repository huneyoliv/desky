import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/theme/theme_palette.dart';

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

Color? _decorationColor(Decoration? decoration) =>
    decoration is BoxDecoration ? decoration.color : null;

Color _nearestBackground(Element element) {
  final theme = Theme.of(element);
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    Color? candidate;
    if (widget is Container) {
      candidate = _decorationColor(widget.decoration) ?? widget.color;
    } else if (widget is DecoratedBox) {
      candidate = _decorationColor(widget.decoration);
    } else if (widget is ColoredBox) {
      candidate = widget.color;
    } else if (widget is Material) {
      candidate = widget.color;
    } else if (widget is Card) {
      candidate = widget.color;
    } else if (widget is Dialog) {
      candidate = widget.backgroundColor;
    } else if (widget is Scaffold) {
      candidate = widget.backgroundColor;
    } else if (widget is AppBar) {
      candidate = widget.backgroundColor;
    } else if (widget is Ink) {
      candidate = _decorationColor(widget.decoration);
    }
    if (candidate != null && candidate.a > 0) {
      layers.add(candidate);
      // An opaque ancestor hides every surface above it.
      if (candidate.a >= 0.999) return false;
    }
    return true;
  });
  var background = theme.scaffoldBackgroundColor;
  for (final layer in layers.reversed) {
    background = Color.alphaBlend(layer, background);
  }
  return background;
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Asserts the effective colour of every visible Text against its nearest
/// opaque ancestor surface. Saturated action backgrounds are not skipped:
/// both light palettes use an onPrimary colour that already passes AA.
void expectRenderedTextContrast(
  WidgetTester tester,
  DeskyThemePalette palette,
  String screen,
) {
  final failures = <String>[];
  for (final element in tester.elementList(find.byType(Text))) {
    final text = element.widget as Text;
    final theme = Theme.of(element);
    final own = text.style;
    final style = own == null || own.inherit
        ? DefaultTextStyle.of(element).style.merge(own)
        : own;
    final foreground = style.color ?? theme.colorScheme.onSurface;
    final background = _nearestBackground(element);
    final effectiveForeground = Color.alphaBlend(foreground, background);
    final ratio = _contrast(effectiveForeground, background);
    if (ratio < 4.5) {
      final key = element.widget.key is ValueKey<String>
          ? (element.widget.key! as ValueKey<String>).value
          : '<sem chave>';
      failures.add(
        '${text.data ?? text.textSpan?.toPlainText() ?? '<vazio>'} '
        '[$key] ${_hex(effectiveForeground)} sobre ${_hex(background)} '
        '= ${ratio.toStringAsFixed(2)}:1',
      );
    }
  }
  expect(
    failures,
    isEmpty,
    reason: '${palette.id}/$screen: texto abaixo de WCAG AA 4.5:1\n'
        '${failures.take(30).join('\n')}',
  );
}

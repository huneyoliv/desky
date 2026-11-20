import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_palette.dart';
import '../stats_data.dart';

/// YPT's statistics orange.
const Color kStatOrange = Color(0xFFFF6B1A);
const Color kStatGray = Color(0xFF8E8E93);
const Color kStatCard = Color(0xFF1C1C1E);

/// Fixed colours for subjects the user has not coloured.
const List<Color> kSubjectFallback = [
  Color(0xFFFF6B6B), Color(0xFF4DABF7), Color(0xFF69DB7C), Color(0xFFFFD43B),
  Color(0xFFDA77F2), Color(0xFFFF922B), Color(0xFF38D9A9), Color(0xFFF783AC),
  Color(0xFF748FFC), Color(0xFFA9E34B), Color(0xFFBDBDBD), Color(0xFF8D6E63),
];

/// Resolves the colour of a subject: its own colour when known, else a
/// stable colour from [kSubjectFallback].
class SubjectColors {
  SubjectColors(this._known);
  final Map<String, Color> _known;

  Color of(String subject) {
    final c = _known[subject];
    if (c != null) return c;
    if (subject == StatsData.unknownSubject) return kStatGray;
    final h = subject.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    return kSubjectFallback[h % kSubjectFallback.length];
  }
}

/// Dark rounded panel with a small grey title, like every YPT stats block.
class StatCard extends StatelessWidget {
  const StatCard({super.key, this.title, this.trailing, required this.child, this.height});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// "Total time / Daily average" style pair of big numbers.
class StatPair extends StatelessWidget {
  const StatPair({super.key, required this.items, this.caption});
  final List<(String, String)> items;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final (label, value) in items)
              Expanded(
                child: Column(
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: kStatOrange)),
                    const SizedBox(height: 2),
                    FittedBox(
                      child: Text(value,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(caption!, style: TextStyle(fontSize: 10, color: context.palette.textMuted)),
          ),
      ],
    );
  }
}

/// One coloured slice of a donut / one legend row.
class Slice {
  const Slice(this.label, this.ms, this.color);
  final String label;
  final int ms;
  final Color color;
}

/// Donut with percentages and a "name   h:mm · %" legend on the right.
class DonutWithLegend extends StatelessWidget {
  const DonutWithLegend({super.key, required this.slices, this.size = 110, this.maxLegend = 20});
  final List<Slice> slices;
  final double size;
  final int maxLegend;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (a, s) => a + s.ms);
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _DonutPainter(slices, total, palette.surface)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in slices.take(maxLegend))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 3, height: 10, color: s.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: palette.textPrimary)),
                      ),
                      Text(
                        '${formatHm(s.ms)} · ${total == 0 ? 0 : (s.ms * 100 / total).round()}%',
                        style: TextStyle(fontSize: 10, color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total, this.hole);
  final List<Slice> slices;
  final int total;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r * 0.78);
    final stroke = r * 0.44;
    if (total <= 0) {
      canvas.drawCircle(c, r * 0.78, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFF3A3A3C));
      return;
    }
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * s.ms / total;
      canvas.drawArc(rect, start, sweep, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color);
      final pct = s.ms * 100 / total;
      if (pct >= 8) {
        final mid = start + sweep / 2;
        final pos = c + Offset(math.cos(mid), math.sin(mid)) * r * 0.78;
        final tp = TextPainter(
          text: TextSpan(
              text: '${pct.round()}%',
              style: const TextStyle(
                  fontFamily: AppTextStyles.fontText,
                  fontFamilyFallback: AppTextStyles.fontFallbacks,
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices || old.total != total;
}

/// One bar: stacked segments from the bottom up.
class BarGroup {
  const BarGroup(this.label, this.segments, {this.highlight = false});
  final String label;
  final List<(double, Color)> segments;
  final bool highlight;
  double get total => segments.fold(0.0, (a, s) => a + s.$1);
}

/// A line drawn over the bars on its own 0..[max] scale (e.g. clock hours).
class OverlayLine {
  const OverlayLine(this.values, this.color, this.max, {this.labels});
  final List<double?> values;
  final Color color;
  final double max;
  final List<String?>? labels;
}

/// Bar chart (optionally stacked) with optional overlay lines and value
/// labels on top. [maxLabel] shows the "Daily max: ..." caption.
class BarsChart extends StatelessWidget {
  const BarsChart({
    super.key,
    required this.groups,
    this.overlays = const [],
    this.height = 140,
    this.maxLabel,
    this.valueLabel,
    this.labelEvery = 1,
  });

  final List<BarGroup> groups;
  final List<OverlayLine> overlays;
  final double height;
  final String? maxLabel;
  final String Function(double)? valueLabel;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxLabel != null)
          Text(maxLabel!, style: TextStyle(fontSize: 9, color: muted)),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsPainter(groups, overlays, muted, valueLabel, labelEvery),
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.groups, this.overlays, this.muted, this.valueLabel, this.labelEvery);
  final List<BarGroup> groups;
  final List<OverlayLine> overlays;
  final Color muted;
  final String Function(double)? valueLabel;
  final int labelEvery;

  @override
  void paint(Canvas canvas, Size size) {
    if (groups.isEmpty) return;
    const labelH = 14.0, topPad = 12.0;
    final chartH = size.height - labelH - topPad;
    final maxV = groups.fold<double>(0, (m, g) => math.max(m, g.total));
    final slot = size.width / groups.length;
    final barW = math.max(2.0, slot * 0.72);

    canvas.drawLine(Offset(0, topPad + chartH), Offset(size.width, topPad + chartH),
        Paint()..color = muted.withValues(alpha: 0.3));

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final x = slot * i + (slot - barW) / 2;
      var y = topPad + chartH;
      for (final (v, color) in g.segments) {
        if (v <= 0 || maxV <= 0) continue;
        final h = chartH * v / maxV;
        canvas.drawRect(Rect.fromLTWH(x, y - h, barW, h), Paint()..color = color);
        y -= h;
      }
      if (g.highlight) {
        canvas.drawRect(Rect.fromLTWH(x - 1, topPad, barW + 2, chartH),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = Colors.white24);
      }
      if (valueLabel != null && g.total > 0) {
        _text(canvas, valueLabel!(g.total), Offset(x + barW / 2, y - 11), 8, Colors.white70);
      }
      if (i % labelEvery == 0 || i == groups.length - 1) {
        _text(canvas, g.label, Offset(slot * i + slot / 2, topPad + chartH + 2), 8, muted);
      }
    }

    for (final line in overlays) {
      final path = Path();
      var started = false;
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < line.values.length && i < groups.length; i++) {
        final v = line.values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final p = Offset(slot * i + slot / 2, topPad + chartH * (1 - v / line.max));
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
        canvas.drawCircle(p, 2, Paint()..color = line.color);
        final label = line.labels?[i];
        if (label != null) _text(canvas, label, p - const Offset(0, 11), 7, line.color);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _text(Canvas c, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: AppTextStyles.fontText,
            fontFamilyFallback: AppTextStyles.fontFallbacks,
            fontSize: size,
            color: color,
          )),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Stacked cumulative areas (one layer per subject), like
/// "Cumulative study time".
class CumulativeAreaChart extends StatelessWidget {
  const CumulativeAreaChart({super.key, required this.layers, this.height = 130, this.reference});

  /// Per layer (bottom first): colour and per-bucket values (not cumulative).
  final List<(Color, List<double>)> layers;
  final double height;

  /// Optional flat target line (e.g. the previous period's total).
  final double? reference;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _AreaPainter(layers, reference, context.palette.textMuted)),
      );
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.layers, this.reference, this.muted);
  final List<(Color, List<double>)> layers;
  final double? reference;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    if (layers.isEmpty || layers.first.$2.isEmpty) return;
    final n = layers.first.$2.length;
    // cumulative stack: stack[l][i] = sum of layers 0..l, cumulative over i.
    final stack = <List<double>>[];
    final running = List<double>.filled(n, 0);
    for (final (_, values) in layers) {
      var acc = 0.0;
      for (var i = 0; i < n; i++) {
        acc += i < values.length ? values[i] : 0;
        running[i] += acc;
      }
      stack.add(List.of(running));
    }
    final maxV = math.max(stack.last.last, reference ?? 0);
    if (maxV <= 0) return;
    double x(int i) => n == 1 ? size.width : size.width * i / (n - 1);
    double y(double v) => size.height - size.height * v / maxV * 0.95;

    for (var l = stack.length - 1; l >= 0; l--) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i < n; i++) {
        path.lineTo(x(i), y(stack[l][i]));
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = layers[l].$1);
    }
    if (reference != null) {
      canvas.drawLine(Offset(0, y(reference!)), Offset(size.width, y(reference!)),
          Paint()..color = Colors.white54);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// "Up to now" comparison: grey filled curve for the reference period and an
/// orange line for the current one, as cumulative values.
class StepCompareChart extends StatelessWidget {
  const StepCompareChart({super.key, required this.current, required this.reference, this.height = 90});
  final List<double> current;
  final List<double> reference;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _StepPainter(current, reference)),
      );
}

class _StepPainter extends CustomPainter {
  _StepPainter(this.current, this.reference);
  final List<double> current;
  final List<double> reference;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(current.length, reference.length);
    if (n < 2) return;
    final maxV = [...current, ...reference, 1.0].reduce(math.max);
    double x(int i) => size.width * i / (n - 1);
    double y(double v) => size.height - size.height * v / maxV;

    final ref = Path()..moveTo(0, size.height);
    for (var i = 0; i < reference.length; i++) {
      ref.lineTo(x(i), y(reference[i]));
      if (i + 1 < reference.length) ref.lineTo(x(i + 1), y(reference[i]));
    }
    ref
      ..lineTo(x(reference.length - 1), size.height)
      ..close();
    canvas.drawPath(ref, Paint()..color = const Color(0xFFD1D1D6).withValues(alpha: 0.85));

    final cur = Path();
    for (var i = 0; i < current.length; i++) {
      final p = Offset(x(i), y(current[i]));
      i == 0 ? cur.moveTo(p.dx, p.dy) : cur.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(cur, Paint()
      ..color = kStatOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    if (current.isNotEmpty) {
      final last = Offset(x(current.length - 1), y(current.last));
      canvas.drawCircle(last, 4, Paint()..color = kStatOrange);
      canvas.drawCircle(last, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Scatter of (x, y) points with two colours, used for start/end time
/// distribution (x = minute of day, y = study hours).
class ScatterChart extends StatelessWidget {
  const ScatterChart({super.key, required this.series, this.height = 120, this.xMax = 1440, this.footer});
  final List<(Color, List<Offset>)> series;
  final double height;
  final double xMax;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: _ScatterPainter(series, xMax, context.palette.textMuted)),
          ),
          if (footer != null) footer!,
        ],
      );
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter(this.series, this.xMax, this.muted);
  final List<(Color, List<Offset>)> series;
  final double xMax;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final yMax = series
        .expand((s) => s.$2)
        .fold<double>(1, (m, p) => math.max(m, p.dy));
    final axis = Paint()..color = muted.withValues(alpha: 0.3);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axis);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), axis);
    for (final (color, pts) in series) {
      for (final p in pts) {
        canvas.drawCircle(
          Offset(size.width * p.dx / xMax, size.height - (size.height - 6) * p.dy / yMax - 3),
          3,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Vertical start→end candles per day ("Study start/end regularity").
class RangeBarsChart extends StatelessWidget {
  const RangeBarsChart({super.key, required this.ranges, this.height = 150});

  /// Per day: start and end as minutes from midnight (end may exceed 1440).
  final List<(double, double)?> ranges;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _RangePainter(ranges, context.palette.textMuted)),
      );
}

class _RangePainter extends CustomPainter {
  _RangePainter(this.ranges, this.muted);
  final List<(double, double)?> ranges;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) return;
    final valid = ranges.whereType<(double, double)>();
    if (valid.isEmpty) return;
    final lo = valid.map((r) => r.$1).reduce(math.min) - 30;
    final hi = valid.map((r) => r.$2).reduce(math.max) + 30;
    final slot = size.width / ranges.length;
    double y(double m) => size.height * (m - lo) / (hi - lo);
    for (var i = 0; i < ranges.length; i++) {
      final r = ranges[i];
      if (r == null) continue;
      final x = slot * i + slot / 2;
      canvas.drawLine(Offset(x, y(r.$1)), Offset(x, y(r.$2)), Paint()
        ..color = kStatOrange.withValues(alpha: 0.75)
        ..strokeWidth = math.max(2, slot * 0.35)
        ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(x, y(r.$1)), 2, Paint()..color = kStatOrange);
      canvas.drawCircle(Offset(x, y(r.$2)), 2, Paint()..color = Colors.white70);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Day timeline: one row per hour, sessions painted across six 10-minute
/// cells in the subject colour (the YPT "planner" grid).
class HourGrid extends StatelessWidget {
  const HourGrid({super.key, required this.sessions, required this.colorOf, this.fromHour = 5});
  final List<StatSession> sessions;
  final Color Function(String) colorOf;
  final int fromHour;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24 * 9.0,
        width: double.infinity,
        child: CustomPaint(
            painter: _HourGridPainter(sessions, colorOf, fromHour, context.palette.border)),
      );
}

class _HourGridPainter extends CustomPainter {
  _HourGridPainter(this.sessions, this.colorOf, this.fromHour, this.line);
  final List<StatSession> sessions;
  final Color Function(String) colorOf;
  final int fromHour;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final rowH = size.height / 24, colW = size.width / 6;
    final grid = Paint()..color = line;
    for (var r = 0; r <= 24; r++) {
      canvas.drawLine(Offset(0, r * rowH), Offset(size.width, r * rowH), grid);
    }
    for (var c = 0; c <= 6; c++) {
      canvas.drawLine(Offset(c * colW, 0), Offset(c * colW, size.height), grid);
    }
    for (final s in sessions) {
      var minute = s.start.hour * 60 + s.start.minute;
      final end = minute + s.ms ~/ 60000;
      final paint = Paint()..color = colorOf(s.subject);
      while (minute < end) {
        final row = ((minute ~/ 60) - fromHour) % 24;
        final segEnd = math.min(end, (minute ~/ 60 + 1) * 60);
        final x0 = (minute % 60) / 10 * colW, x1 = ((segEnd - 1) % 60 + 1) / 10 * colW;
        canvas.drawRect(Rect.fromLTRB(x0, row * rowH + 1, x1, (row + 1) * rowH - 1), paint);
        minute = segEnd;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Orange intensity used by every calendar / period grid.
Color heatColor(int ms, int maxMs) {
  if (ms <= 0 || maxMs <= 0) return const Color(0xFF2C2C2E);
  final t = (ms / maxMs).clamp(0.15, 1.0);
  return Color.lerp(const Color(0xFF4A2410), kStatOrange, t)!;
}

/// Grid of selectable tiles (months of a year, weeks of a quarter), each with
/// a caption and its total.
class PeriodGrid extends StatelessWidget {
  const PeriodGrid({
    super.key,
    required this.tiles,
    required this.columns,
    required this.onTap,
  });

  /// (caption, total ms, selected, enabled)
  final List<(String, int, bool, bool)> tiles;
  final int columns;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final maxMs = tiles.fold<int>(0, (m, t) => math.max(m, t.$2));
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        for (var i = 0; i < tiles.length; i++)
          GestureDetector(
            onTap: tiles[i].$4 ? () => onTap(i) : null,
            child: Container(
              decoration: BoxDecoration(
                color: tiles[i].$4 ? heatColor(tiles[i].$2, maxMs) : Colors.transparent,
                border: Border.all(
                    color: tiles[i].$3 ? Colors.white70 : Colors.black26, width: tiles[i].$3 ? 1.5 : 0.5),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tiles[i].$1,
                      style: TextStyle(fontSize: 10, color: tiles[i].$4 ? Colors.white : Colors.white38)),
                  if (tiles[i].$2 > 0)
                    Text(formatHms(tiles[i].$2),
                        style: const TextStyle(fontSize: 9, color: Colors.white70)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact text legend under stacked charts.
class SubjectLegend extends StatelessWidget {
  const SubjectLegend({super.key, required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          for (final (label, color) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, color: color),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: context.palette.textSecondary)),
                ),
              ],
            ),
        ],
      );
}

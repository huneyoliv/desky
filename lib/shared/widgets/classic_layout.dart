import 'package:flutter/material.dart';
import '../../core/theme/theme_palette.dart';

/// Width at which Classic screens switch from one column to two panes.
const double kClassicWideBreakpoint = 900;

/// Centres a Classic screen and caps its width, so a 1920 px window reads like
/// a tablet instead of stretching rows edge to edge.
class ClassicPage extends StatelessWidget {
  const ClassicPage({super.key, required this.child, this.maxWidth = 1240, this.scroll = false});

  final Widget child;
  final double maxWidth;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), child: child),
      ),
    );
    return scroll ? SingleChildScrollView(child: content) : content;
  }
}

/// Rounded panel used by every Classic screen.
class ClassicCard extends StatelessWidget {
  const ClassicCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.title, this.trailing});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
      ),
      padding: padding,
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title!,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  ),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: 12),
                Flexible(child: child),
              ],
            ),
    );
  }
}

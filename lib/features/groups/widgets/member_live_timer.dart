import 'dart:async';

import 'package:flutter/material.dart';

/// Live elapsed-time counter for a group member row.
///
/// Shows a ticking timer computed **locally** from the API's `dl.st`, refreshed
/// every second without any network request, so the row stops freezing between
/// the 30-second polls. It runs only while the member is studying and not
/// paused and only when the API reported a parseable start; in every other case
/// it renders [staticLabel], the display that existed before.
///
/// The counter deliberately uses nothing but `dl.st`: the meaning and unit of
/// the member accumulators (`sm`, `am`, `mm`) could not be confirmed, so they
/// are not interpreted here.
class MemberLiveTimer extends StatefulWidget {
  const MemberLiveTimer({
    super.key,
    required this.isStudying,
    required this.isPaused,
    required this.sessionStartedAt,
    required this.staticLabel,
    required this.activePrefix,
    required this.style,
    this.nowProvider = defaultNow,
  });

  final bool isStudying;
  final bool isPaused;
  final DateTime? sessionStartedAt;
  final String staticLabel;
  final String activePrefix;
  final TextStyle style;
  final DateTime Function() nowProvider;

  static DateTime defaultNow() => DateTime.now();

  @override
  State<MemberLiveTimer> createState() => _MemberLiveTimerState();
}

class _MemberLiveTimerState extends State<MemberLiveTimer> {
  Timer? _ticker;

  bool get _isActive =>
      widget.isStudying && !widget.isPaused && widget.sessionStartedAt != null;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant MemberLiveTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStudying != widget.isStudying ||
        oldWidget.isPaused != widget.isPaused ||
        oldWidget.sessionStartedAt != widget.sessionStartedAt) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    if (_isActive && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_isActive && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActive) {
      return Text(widget.staticLabel, style: widget.style);
    }
    final elapsed = widget.nowProvider().difference(widget.sessionStartedAt!);
    return Text(
      '${widget.activePrefix} (${formatElapsed(elapsed)})',
      style: widget.style,
    );
  }
}

/// `mm:ss` under one hour, `h:mm:ss` from one hour on; never negative.
String formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
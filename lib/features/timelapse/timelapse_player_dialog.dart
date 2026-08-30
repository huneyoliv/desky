import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/timelapse_session_model.dart';

class TimelapsePlayerDialog extends ConsumerStatefulWidget {
  final TimelapseSession session;

  const TimelapsePlayerDialog({super.key, required this.session});

  static Future<void> show(BuildContext context, TimelapseSession session) {
    return showDialog(
      context: context,
      builder: (_) => TimelapsePlayerDialog(session: session),
    );
  }

  @override
  ConsumerState<TimelapsePlayerDialog> createState() => _TimelapsePlayerDialogState();
}

class _TimelapsePlayerDialogState extends ConsumerState<TimelapsePlayerDialog> {
  int _currentFrameIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 10.0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    if (widget.session.frameCount > 0) {
      _startPlayback();
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    if (widget.session.frameCount <= 1) return;

    final intervalMs = (1000 / _playbackSpeed).round().clamp(16, 2000);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) return;
      setState(() {
        if (_currentFrameIndex + 1 < widget.session.frameCount) {
          _currentFrameIndex++;
        } else {
          _currentFrameIndex = 0;
        }
      });
    });
    setState(() => _isPlaying = true);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      _startPlayback();
    }
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (_isPlaying) {
      _startPlayback();
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      return '${h}h ${m % 60}m';
    }
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final session = widget.session;
    final subjectColor = ColorUtils.fromArgbInt(session.subjectColorInt);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: subjectColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        session.subjectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${t.tr("study", fallback: "Estudo")}: ${_formatDuration(session.durationSeconds)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildFrameView(t),
              ),
              const SizedBox(height: 16),
              if (session.frameCount > 0) ...[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withAlpha(50),
                  ),
                  child: Slider(
                    value: _currentFrameIndex.toDouble().clamp(0.0, (session.frameCount - 1).toDouble()),
                    min: 0,
                    max: (session.frameCount - 1).toDouble(),
                    onChanged: (val) {
                      setState(() {
                        _currentFrameIndex = val.round();
                      });
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Frame ${_currentFrameIndex + 1} / ${session.frameCount}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(t.tr('speed', fallback: 'Velocidade: '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        for (final sp in [1.0, 5.0, 10.0, 30.0, 60.0])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ChoiceChip(
                              label: Text('${sp.toInt()}x', style: TextStyle(color: _playbackSpeed == sp ? Colors.white : AppColors.textSecondary, fontSize: 11)),
                              selected: _playbackSpeed == sp,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceLight,
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onSelected: (_) => _changeSpeed(sp),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrameView(AppTranslation t) {
    if (widget.session.frameCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(t.tr('no_frames_recorded', fallback: 'Nenhum frame gravado nesta sessão.'), style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final framePath = widget.session.framePaths[_currentFrameIndex];
    final file = File(framePath);

    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.slow_motion_video_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Timelapse • Frame ${_currentFrameIndex + 1} / ${widget.session.frameCount}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            widget.session.subjectName,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

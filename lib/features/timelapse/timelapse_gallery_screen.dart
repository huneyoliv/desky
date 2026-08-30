import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/timelapse_session_model.dart';
import 'timelapse_notifier.dart';
import 'timelapse_player_dialog.dart';

class TimelapseGalleryScreen extends ConsumerWidget {
  const TimelapseGalleryScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelapseNotifierProvider);
    final notifier = ref.read(timelapseNotifierProvider.notifier);
    final t = ref.watch(appTranslationProvider);

    final totalSeconds = state.sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          t.tr('timelapse_gallery', fallback: 'Galeria de Timelapse'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => notifier.loadSessions(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : state.sessions.isEmpty
              ? _buildEmptyState(context, t)
              : _buildGalleryContent(context, state.sessions, notifier, totalSeconds, t),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTranslation t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.slow_motion_video_rounded, size: 72, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            t.tr('no_timelapse', fallback: 'Nenhum timelapse gravado ainda'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.tr('timelapse_empty_desc', fallback: 'Inicie o cronômetro com a câmera/timelapse ativado para gravar seu progresso acelerado.'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryContent(
    BuildContext context,
    List<TimelapseSession> sessions,
    TimelapseNotifier notifier,
    int totalSeconds,
    AppTranslation t,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard(
                title: t.tr('total_videos', fallback: 'Total de Vídeos'),
                value: '${sessions.length}',
                icon: Icons.video_library_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: t.tr('recorded_time', fallback: 'Tempo Gravado'),
                value: _formatDuration(totalSeconds),
                icon: Icons.access_time_filled_rounded,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t.tr('study_sessions', fallback: 'Sessões de Estudo'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                childAspectRatio: 1.1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(context, session, notifier, t);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    TimelapseSession session,
    TimelapseNotifier notifier,
    AppTranslation t,
  ) {
    final subjectColor = ColorUtils.fromArgbInt(session.subjectColorInt);
    final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(session.startTime);

    return InkWell(
      onTap: () => TimelapsePlayerDialog.show(context, session),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Colors.black45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (session.thumbnailPath != null && File(session.thumbnailPath!).existsSync())
                      Image.file(File(session.thumbnailPath!), fit: BoxFit.cover)
                    else
                      Center(
                        child: Icon(Icons.slow_motion_video_rounded, size: 48, color: subjectColor.withAlpha(180)),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(session.durationSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: subjectColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                session.subjectName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                    onPressed: () => notifier.deleteSession(session.id),
                    tooltip: t.tr('delete_timelapse', fallback: 'Excluir Timelapse'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

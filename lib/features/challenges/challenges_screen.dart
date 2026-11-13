import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/challenge_model.dart';
import '../../data/repositories/challenge_repository.dart';

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository();
});

/// Lista de desafios em modo **somente leitura**.
///
/// As acoes de participar, cancelar, "meus desafios" e check-in foram removidas:
/// as rotas usadas ate entao (`/mission/challenge/join`, `/cancel`, `/my`) nao
/// existem na API (`404`) e nem aparecem no APK oficial, e o check-in anterior
/// apenas exibia uma mensagem de sucesso sem chamar a API.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  List<ChallengeModel> _available = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    final repo = ref.read(challengeRepositoryProvider);

    final available = await repo.fetchAvailableChallenges();

    if (mounted) {
      setState(() {
        _available = available;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        title: Text(t.tr('challenges', fallback: 'Desafios & Metas'),
            style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.tr('refresh', fallback: 'Atualizar'),
            onPressed: _loadChallenges,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.appPrimary))
          : _available.isEmpty
              ? _buildEmptyState(t)
              : _buildChallengeGrid(_available, t),
    );
  }

  Widget _buildEmptyState(AppTranslation t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: context.appTextMuted),
            const SizedBox(height: 16),
            Text(
              t.tr('no_challenges', fallback: 'Nenhum desafio disponível no momento.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              t.tr('challenges_read_only',
                  fallback: 'Esta lista é somente para consulta: participar e cancelar ainda não são suportados.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeGrid(List<ChallengeModel> list, AppTranslation t) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        childAspectRatio: 0.95,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final challenge = list[index];
        final df = DateFormat('dd/MM');

        return Card(
          color: context.appCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.appBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '⭐ ${challenge.flameCost} ${t.tr("points", fallback: "pts")}',
                        style: TextStyle(
                          color: context.appPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${t.tr("goal", fallback: "Meta")}: ${(challenge.successThreshold * 100).toInt()}%',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.appTextMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  challenge.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  challenge.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: context.appTextMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${df.format(challenge.startDate)} - ${df.format(challenge.endDate)}',
                      style: TextStyle(color: context.appTextMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    Icon(Icons.people_outline, size: 14, color: context.appTextMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.participantCount}',
                      style: TextStyle(color: context.appTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
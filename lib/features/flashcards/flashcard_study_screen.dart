import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import 'flashcard_notifier.dart';

class FlashcardStudyScreen extends ConsumerWidget {
  const FlashcardStudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flashcardNotifierProvider);
    final notifier = ref.read(flashcardNotifierProvider.notifier);
    final t = ref.watch(appTranslationProvider);
    final deck = state.selectedDeck;

    if (deck == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: Center(
          child: Text(t.tr('no_deck_selected', fallback: 'Nenhum baralho selecionado.'), style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(deck.title), backgroundColor: AppColors.surface),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (state.currentCards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(deck.title),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(t.tr('deck_empty_cards', fallback: 'Este baralho ainda não tem cartões.'),
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: Text(t.tr('back', fallback: 'Voltar')),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isSessionCompleted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(deck.title), backgroundColor: AppColors.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration_rounded, size: 80, color: AppColors.warning),
              const SizedBox(height: 20),
              Text(
                t.tr('session_completed', fallback: 'Sessão Concluída!'),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '${t.tr("reviewed_all", fallback: "Você revisou todos os")} ${state.currentCards.length} ${t.tr("cards_in_deck", fallback: "cartões deste baralho.")}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => notifier.restartSession(),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(t.tr('review_again', fallback: 'Revisar Novamente')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(t.tr('done', fallback: 'Concluir'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final card = state.activeCard!;
    final total = state.currentCards.length;
    final current = state.currentCardIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(deck.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                '$current / $total',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(deck.color),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Card Interactive Area
              Expanded(
                child: GestureDetector(
                  onTap: () => notifier.flipCard(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: state.isFlipped ? deck.color : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (state.isFlipped ? deck.color : Colors.black).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: (state.isFlipped ? AppColors.success : deck.color).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.isFlipped
                                ? t.tr('back_answer', fallback: 'VERSO (RESPOSTA)')
                                : t.tr('front_question', fallback: 'FRENTE (PERGUNTA)'),
                            style: TextStyle(
                              color: state.isFlipped ? AppColors.success : deck.color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          state.isFlipped ? card.back : card.front,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        if (!state.isFlipped && card.hint != null && card.hint!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Text(
                                  '${t.tr("hint", fallback: "Dica")}: ${card.hint!}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              t.tr('tap_to_flip', fallback: 'Toque para virar'),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons (Show answer or review rating)
              if (!state.isFlipped)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => notifier.flipCard(),
                    icon: const Icon(Icons.visibility_outlined, color: Colors.white),
                    label: Text(
                      t.tr('show_answer', fallback: 'Mostrar Resposta'),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deck.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildEaseButton(
                        label: t.tr('hard', fallback: 'Difícil'),
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        onTap: () => notifier.answerCard(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEaseButton(
                        label: t.tr('good', fallback: 'Bom'),
                        icon: Icons.thumb_up_alt_outlined,
                        color: AppColors.primary,
                        onTap: () => notifier.answerCard(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEaseButton(
                        label: t.tr('easy', fallback: 'Fácil'),
                        icon: Icons.sentiment_very_satisfied_outlined,
                        color: AppColors.success,
                        onTap: () => notifier.answerCard(3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEaseButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

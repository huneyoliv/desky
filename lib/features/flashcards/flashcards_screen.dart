import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/flashcard_model.dart';
import 'flashcard_notifier.dart';
import 'flashcard_study_screen.dart';
import '../../core/services/smartbook_window_service.dart';
import 'widgets/create_deck_dialog.dart';
import 'widgets/create_card_dialog.dart';

class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flashcardNotifierProvider);
    final notifier = ref.read(flashcardNotifierProvider.notifier);
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.tr('flashcards', fallback: 'Flashcards'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 24),
            tooltip: t.tr('open_pdf_reader', fallback: 'Abrir Leitor de PDF'),
            onPressed: () {
              SmartBookWindowService.open(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
            tooltip: t.tr('new_deck', fallback: 'Novo Baralho'),
            onPressed: () {
              CreateDeckDialog.show(
                context,
                onSave: (title, colorInt, desc) {
                  notifier.createDeck(title: title, colorInt: colorInt, description: desc);
                },
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : state.decks.isEmpty
              ? _buildEmptyState(context, ref, notifier, t)
              : _buildDeckGrid(context, ref, state.decks, t),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, FlashcardNotifier notifier, AppTranslation t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            t.tr('no_flashcards', fallback: 'Nenhum baralho criado ainda'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.tr('flashcard_desc', fallback: 'Crie baralhos e adicione cartões para acelerar seus estudos.'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              CreateDeckDialog.show(
                context,
                onSave: (title, colorInt, desc) {
                  notifier.createDeck(title: title, colorInt: colorInt, description: desc);
                },
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(t.tr('new_deck', fallback: 'Criar Baralho'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckGrid(
    BuildContext context,
    WidgetRef ref,
    List<FlashcardDeckModel> decks,
    AppTranslation t,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 180,
            ),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return _buildDeckCard(context, ref, deck, t);
            },
          );
        },
      ),
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardDeckModel deck,
    AppTranslation t,
  ) {
    final notifier = ref.read(flashcardNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: deck.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  deck.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'add') {
                    notifier.selectDeck(deck);
                    CreateCardDialog.show(
                      context,
                      onSave: (front, back, hint) {
                        notifier.createCard(front: front, back: back, hint: hint);
                      },
                    );
                  } else if (val == 'delete') {
                    notifier.deleteDeck(deck.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(t.tr('add_card', fallback: 'Adicionar Cartão'), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Text(t.tr('delete_deck', fallback: 'Excluir Baralho'), style: const TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (deck.description != null && deck.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              deck.description!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${deck.cardCount} ${t.tr("cards", fallback: "cartões")}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await notifier.selectDeck(deck);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FlashcardStudyScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                label: Text(t.tr('study', fallback: 'Estudar'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deck.color,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/sticker_model.dart';
import '../../../data/repositories/chat_media_repository.dart';

import '../../../core/localization/app_translation.dart';

final chatMediaRepoProvider = Provider<ChatMediaRepository>((ref) {
  return ChatMediaRepository();
});

class StickerPickerPanel extends ConsumerStatefulWidget {
  final ValueChanged<Sticker> onStickerSelected;

  const StickerPickerPanel({
    super.key,
    required this.onStickerSelected,
  });

  @override
  ConsumerState<StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends ConsumerState<StickerPickerPanel> {
  List<StickerSet> _sets = [];
  StickerSet? _selectedSet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStickerSets();
  }

  Future<void> _loadStickerSets() async {
    setState(() => _isLoading = true);
    final repo = ref.read(chatMediaRepoProvider);
    final sets = await repo.fetchStickerSets();

    if (mounted) {
      setState(() {
        _sets = sets;
        _selectedSet = sets.isNotEmpty ? sets.first : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Header Bar: Sets selector
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.card,
                  child: Row(
                    children: [
                      Text(
                        t.tr('ypt_stickers', fallback: 'Figurinhas YPT'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sets.length,
                          itemBuilder: (context, index) {
                            final set = _sets[index];
                            final isSelected = _selectedSet?.id == set.id;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(set.name),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedSet = set);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Stickers Grid
                Expanded(
                  child: _selectedSet == null || _selectedSet!.stickers.isEmpty
                      ? Center(
                          child: Text(
                            t.tr('no_stickers_available', fallback: 'Nenhuma figurinha disponível.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _selectedSet!.stickers.length,
                          itemBuilder: (context, index) {
                            final sticker = _selectedSet!.stickers[index];

                            return InkWell(
                              onTap: () => widget.onStickerSelected(sticker),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.network(
                                  sticker.url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.extension_rounded,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/studicon_item_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/store_repository.dart';
import '../../../shared/widgets/studicon_avatar.dart';
import '../../auth/auth_notifier.dart';

class GroupStudiconPickerDialog extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;
  final int currentStudiconId;
  final String? currentNickname;

  const GroupStudiconPickerDialog({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentStudiconId,
    this.currentNickname,
  });

  static Future<int?> show(
    BuildContext context, {
    required int groupId,
    required String groupName,
    required int currentStudiconId,
    String? currentNickname,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) => GroupStudiconPickerDialog(
        groupId: groupId,
        groupName: groupName,
        currentStudiconId: currentStudiconId,
        currentNickname: currentNickname,
      ),
    );
  }

  @override
  ConsumerState<GroupStudiconPickerDialog> createState() => _GroupStudiconPickerDialogState();
}

class _GroupStudiconPickerDialogState extends ConsumerState<GroupStudiconPickerDialog> {
  late int _selectedStudiconId;
  List<StudiconItemModel> _availableStudicons = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStudiconId = widget.currentStudiconId;
    _loadStudicons();
  }

  Future<void> _loadStudicons() async {
    final user = ref.read(authStateProvider).user;
    final storeRepo = StoreRepository();
    final items = await storeRepo.fetchMyStudicons(
      widget.currentStudiconId,
      ownedIdsFromUser: user?.ownedStudiconIds,
    );

    if (mounted) {
      setState(() {
        _availableStudicons = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGroupStudicon() async {
    setState(() => _isSaving = true);
    final groupRepo = GroupRepository();
    final t = ref.read(appTranslationProvider);

    final success = await groupRepo.updateGroupMemberStudicon(
      groupId: widget.groupId,
      studiconId: _selectedStudiconId,
      nickname: widget.currentNickname,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.tr('group_avatar_updated', fallback: 'Avatar do grupo atualizado com sucesso! 🎉')),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop(_selectedStudiconId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.tr('failed_update_group_avatar', fallback: 'Falha ao atualizar o avatar do grupo.')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.tr('group_avatar', fallback: 'Avatar do Grupo'),
                        style: AppTextStyles.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.groupName} • ${t.tr("select_group_avatar_desc", fallback: "Escolha um avatar para exibir neste grupo:")}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _availableStudicons.isEmpty
                      ? Center(
                          child: Text(
                            t.tr('no_avatars', fallback: 'Nenhum avatar disponível.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _availableStudicons.length,
                          itemBuilder: (context, index) {
                            final item = _availableStudicons[index];
                            final isSelected = item.id == _selectedStudiconId;
                            final itemName = item.id == -1
                                ? t.tr('default_avatar', fallback: 'Avatar Padrão')
                                : item.name;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedStudiconId = item.id;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    StudiconAvatar(
                                      studiconId: item.id,
                                      size: 65,
                                    ),
                                    Tooltip(
                                      message: item.description ?? itemName,
                                      child: Text(
                                        itemName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.primaryLight : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.tr('selected', fallback: 'SELECIONADO').toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    t.tr('cancel', fallback: 'Cancelar'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveGroupStudicon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          t.tr('apply', fallback: 'Definir para este Grupo'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

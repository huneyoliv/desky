import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/studicon_item_model.dart';
import '../../data/repositories/store_repository.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  List<StudiconItemModel> _myStudicons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyStudicons();
  }

  Future<void> _loadMyStudicons() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).user;
    final repo = ref.read(storeRepositoryProvider);
    final myItems = await repo.fetchMyStudicons(
      user?.studiconId ?? -1,
      ownedIdsFromUser: user?.ownedStudiconIds,
    );

    if (mounted) {
      setState(() {
        _myStudicons = myItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _equipItem(StudiconItemModel item) async {
    setState(() {
      _myStudicons = _myStudicons.map((i) {
        if (i.id == item.id) {
          return i.copyWith(isEquipped: true);
        }
        return i.copyWith(isEquipped: false);
      }).toList();
    });

    final repo = ref.read(storeRepositoryProvider);
    final t = ref.read(appTranslationProvider);
    final itemName = item.id == -1 ? t.tr('default_avatar', fallback: 'Avatar Padrão') : item.name;
    await ref.read(authStateProvider.notifier).updateStudicon(item.id);
    await repo.equipStudicon(item.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.tr("avatar", fallback: "Avatar")} "$itemName" ${t.tr("equipped_success", fallback: "equipado com sucesso!")} 🎉'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.tr('my_avatars', fallback: 'Meus Avatares'), style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.tr('refresh', fallback: 'Atualizar'),
            onPressed: _loadMyStudicons,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _myStudicons.isEmpty
              ? Center(
                  child: Text(
                    t.tr('no_avatars', fallback: 'Nenhum avatar encontrado.'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _myStudicons.length,
                  itemBuilder: (context, index) {
                    final item = _myStudicons[index];
                    final itemName = item.id == -1 ? t.tr('default_avatar', fallback: 'Avatar Padrão') : item.name;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isEquipped ? AppColors.primary : AppColors.border,
                          width: item.isEquipped ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StudiconAvatar(studiconId: item.id, size: 85),
                          Tooltip(
                            message: item.description ?? itemName,
                            child: Text(
                              itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (item.isEquipped)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  t.tr('equipped', fallback: 'EQUIPADO').toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _equipItem(item),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                child: Text(
                                  t.tr('equip', fallback: 'Equipar'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

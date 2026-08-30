import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/studicon_item_model.dart';

class StoreRepository {
  final ApiClient _apiClient;

  StoreRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<StudiconItemModel>> fetchCatalog({
    List<int>? extraOwnedIds,
    String language = 'pt',
  }) async {
    final Map<int, StudiconItemModel> catalogMap = {};
    final Set<int> ownedIds = {};

    if (extraOwnedIds != null) {
      for (final id in extraOwnedIds) {
        if (id > 0) ownedIds.add(id);
      }
    }

    try {
      final myResp = await _apiClient.get(
        '/studicon/my/list',
        queryParameters: {'lang': language},
      );
      if (myResp.data is Map<String, dynamic> && myResp.data['s'] == true) {
        final myRaw = myResp.data['my'];
        if (myRaw is List) {
          for (final item in myRaw) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] as int? ?? 0;
              if (id > 0) ownedIds.add(id);
            } else if (item is int) {
              if (item > 0) ownedIds.add(item);
            }
          }
        }
      }
    } catch (_) {}

    // Fetch all pages of famous
    for (int p = 1; p <= 6; p++) {
      try {
        final famousResp = await _apiClient.get(
          '/studicon/list/famous',
          baseUrl: ApiConstants.metadataCdnUrl,
          queryParameters: {'p': p, 'lang': language},
        );
        if (famousResp.data is Map<String, dynamic> && famousResp.data['s'] == true) {
          final scs = famousResp.data['scs'];
          if (scs is List && scs.isNotEmpty) {
            for (final item in scs) {
              if (item is Map<String, dynamic>) {
                final model = StudiconItemModel.fromJson(item);
                final isOwned = ownedIds.contains(model.id);
                catalogMap[model.id] = model.copyWith(isOwned: isOwned);
              }
            }
            final hasMore = famousResp.data['hm'] == true;
            if (!hasMore) break;
          } else {
            break;
          }
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }

    // Fetch all pages of new
    for (int p = 1; p <= 6; p++) {
      try {
        final newResp = await _apiClient.get(
          '/studicon/list/new',
          baseUrl: ApiConstants.metadataCdnUrl,
          queryParameters: {'p': p, 'lang': language},
        );
        if (newResp.data is Map<String, dynamic> && newResp.data['s'] == true) {
          final scs = newResp.data['scs'];
          if (scs is List && scs.isNotEmpty) {
            for (final item in scs) {
              if (item is Map<String, dynamic>) {
                final model = StudiconItemModel.fromJson(item);
                if (!catalogMap.containsKey(model.id)) {
                  final isOwned = ownedIds.contains(model.id);
                  catalogMap[model.id] = model.copyWith(isOwned: isOwned);
                }
              }
            }
            final hasMore = newResp.data['hm'] == true;
            if (!hasMore) break;
          } else {
            break;
          }
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }

    for (final id in ownedIds) {
      if (!catalogMap.containsKey(id)) {
        catalogMap[id] = StudiconItemModel(
          id: id,
          name: 'Avatar #$id',
          category: 'Meus Avatares',
          priceFlames: 0,
          isOwned: true,
        );
      }
    }

    return catalogMap.values.toList();
  }

  Future<List<StudiconItemModel>> fetchMyStudicons(
    int currentEquippedId, {
    List<int>? ownedIdsFromUser,
    String language = 'pt',
  }) async {
    final extraIds = <int>[];
    if (ownedIdsFromUser != null) {
      extraIds.addAll(ownedIdsFromUser);
    }
    if (currentEquippedId > 0 && !extraIds.contains(currentEquippedId)) {
      extraIds.add(currentEquippedId);
    }

    final catalog = await fetchCatalog(extraOwnedIds: extraIds, language: language);
    final myItems = <StudiconItemModel>[];

    // Always provide the standard orange doll avatar (-1) as the default item
    myItems.add(
      StudiconItemModel(
        id: -1,
        name: 'Boneco Padrão (Laranja)',
        category: 'Padrão',
        priceFlames: 0,
        isOwned: true,
        isEquipped: currentEquippedId <= 0 || currentEquippedId == -1,
      ),
    );

    for (final item in catalog) {
      if (item.isOwned) {
        myItems.add(item.copyWith(isEquipped: item.id == currentEquippedId));
      }
    }

    return myItems;
  }

  Future<bool> equipStudicon(int studiconId) async {
    try {
      final response = await _apiClient.post(
        '/user/studicon',
        data: {'sd': studiconId, 'studiconId': studiconId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return true;
  }
}

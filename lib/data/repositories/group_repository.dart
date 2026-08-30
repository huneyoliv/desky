import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/study_date_helper.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/chat_message_model.dart';

class GroupRepository {
  final ApiClient _apiClient;

  GroupRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<GroupMemberModel>> fetchMembers(
    int groupId, {
    int countryId = ApiConstants.defaultCountryId,
    int version = ApiConstants.defaultVersion,
  }) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.groupMembers}?groupID=$groupId&countryID=$countryId&isLooking=false&version=$version',
      );

      final data = response.data;
      if (data is Map) {
        final list = data['ms'] ?? data['members'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => GroupMemberModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get(
        '${ApiConstants.groupMembers}?groupID=$groupId',
      );
      final data = response.data;
      if (data is Map) {
        final list = data['ms'] ?? data['members'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => GroupMemberModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<List<GroupMemberModel>> fetchGroupRanks(
    int groupId, {
    String period = 'week',
    int countryId = ApiConstants.defaultCountryId,
    int categoryId = 0,
  }) async {
    try {
      final dateStr = StudyDateHelper.getStudyDateString();
      dynamic data;
      try {
        final response = await _apiClient.get(
          '${ApiConstants.metadataCdnUrl}/logs/group/member/ranks?type=$period&countryID=$countryId&categoryID=$categoryId&groupID=$groupId&isCam=false&date=$dateStr&page=1',
        );
        data = response.data;
      } catch (_) {
        final response = await _apiClient.get(
          '/logs/group/member/ranks?type=$period&countryID=$countryId&categoryID=$categoryId&groupID=$groupId&isCam=false&date=$dateStr&page=1',
        );
        data = response.data;
      }

      if (data is Map) {
        final list = data['ms'] ?? data['ranks'] ?? data['list'] ?? data['members'];
        if (list is List) {
          final members = list
              .whereType<Map>()
              .map((m) => GroupMemberModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          members.sort((a, b) => b.studyMs.compareTo(a.studyMs));
          return members;
        }
      } else if (data is List) {
        final members = data
            .whereType<Map>()
            .map((m) => GroupMemberModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        members.sort((a, b) => b.studyMs.compareTo(a.studyMs));
        return members;
      }
    } catch (_) {}
    return [];
  }

  Future<List<GroupMemberModel>> fetchWeeklyRanks(
    int groupId, {
    int countryId = ApiConstants.defaultCountryId,
    int categoryId = 0,
  }) =>
      fetchGroupRanks(groupId, period: 'week', countryId: countryId, categoryId: categoryId);

  Future<bool> shakeMember({required int groupId, required int targetUserId}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.groupShake,
        data: {
          'groupID': groupId,
          'targetUserID': targetUserId,
        },
      );

      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> shakeAllMembers(int groupId) async {
    try {
      final response = await _apiClient.post(
        '/group/push/shake/all',
        data: {'groupID': groupId},
      );
      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<List<ChatMessageModel>> fetchChatMessages(int groupId) async {
    try {
      final response = await _apiClient.get(
        '/chat/group/messages?group_id=$groupId&include_meta=true',
      );

      final data = response.data;
      if (data is Map) {
        final list = data['m'] ?? data['messages'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => ChatMessageModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<ChatMessageModel> sendMessage({
    required int groupId,
    String nickname = 'Usuário',
    int userId = 0,
    String message = '',
    int category = 0,
    String? stickerUrl,
    String? imageUrl,
    String? thumbUrl,
  }) async {
    final payload = <String, dynamic>{
      'group_id': groupId,
      'nickname': nickname,
      'category': category,
      'userID': userId,
      'message': message.isNotEmpty ? message : (imageUrl != null ? 'Photo' : ''),
      'createdAt': null,
      'updatedAt': null,
    };
    if (stickerUrl != null) payload['stickerUrl'] = stickerUrl;
    if (imageUrl != null) {
      payload['img'] = imageUrl;
      payload['imageUrl'] = imageUrl;
    }
    if (thumbUrl != null) {
      payload['th'] = thumbUrl;
    }

    final response = await _apiClient.post(
      '/chat/group/message',
      data: payload,
    );

    final data = response.data;
    if (data is! Map || (data['s'] != true && data['idx'] == null)) {
      throw Exception(data is Map ? data['m'] : 'Falha ao enviar mensagem');
    }

    return ChatMessageModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<bool> sendReaction({
    required int groupId,
    required int messageId,
    required String emoji,
  }) async {
    try {
      final response = await _apiClient.post(
        '/chat/group/reaction',
        data: {
          'group_id': groupId,
          'idx': messageId,
          'reaction': emoji,
        },
      );
      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<List<GroupModel>> fetchExploreGroups({
    int categoryId = 0,
    String orderType = 'promotedAt',
    int page = 1,
    int countryId = 23,
    String? query,
  }) async {
    try {
      final queryParams = <String, String>{
        'category_id': categoryId.toString(),
        'order_type': orderType,
        'only_available': 'false',
        'only_open': 'false',
        'only_cam': 'false',
        'page': page.toString(),
        'country_id': countryId.toString(),
        'p': 'true',
      };
      if (query != null && query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final response = await _apiClient.get('/group/list-new-2?$queryString');

      final data = response.data;
      if (data is Map) {
        final list = data['gs'] ?? data['g'] ?? data['groups'] ?? data['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((g) => GroupModel.fromJson(Map<String, dynamic>.from(g)))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<List<GroupModel>> searchGroups(String query, {int categoryId = 0, int countryId = 23}) async {
    return fetchExploreGroups(query: query, categoryId: categoryId, countryId: countryId);
  }

  Future<Map<String, dynamic>?> fetchGroupSearchInfo(int groupId) async {
    try {
      final response = await _apiClient.get('/group/search-info/v2?groupID=$groupId');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateGroupNotice({required int groupId, required String notice}) async {
    try {
      final response = await _apiClient.post(
        '/group/notice',
        data: {
          'groupID': groupId,
          'notice': notice,
        },
      );
      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> joinGroup(
    int groupId, {
    String? nickname,
    int? studiconId,
    String? password,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': groupId,
        'release': true,
        'canCam': true,
        'studiconID': studiconId,
        'nickname': nickname ?? 'Usuário',
        'p': true,
      };
      if (password != null && password.isNotEmpty) {
        payload['pw'] = password;
      }

      final response = await _apiClient.post(
        '/group/join/v2',
        data: payload,
      );
      final data = response.data;
      if (data is Map && data['s'] == true) {
        return true;
      }
    } catch (_) {}

    try {
      final response = await _apiClient.post(
        '/group/join/v2',
        data: {'group_id': groupId, 'id': groupId},
      );
      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateGroupMemberStudicon({
    required int groupId,
    required int studiconId,
    String? nickname,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': groupId,
        'studiconID': studiconId,
        'release': true,
        'canCam': true,
        'p': true,
      };
      if (nickname != null && nickname.isNotEmpty) {
        payload['nickname'] = nickname;
      }

      final response = await _apiClient.post(
        '/group/join/v2',
        data: payload,
      );
      final data = response.data;
      if (data is Map && data['s'] == true) {
        return true;
      }
    } catch (_) {}

    try {
      final response = await _apiClient.post(
        '/group/member/setting',
        data: {
          'groupID': groupId,
          'studiconID': studiconId,
          if (nickname != null) 'nickname': nickname,
        },
      );
      final data = response.data;
      if (data is Map && data['s'] == true) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> leaveGroup(int groupId) async {
    try {
      final response = await _apiClient.post(
        '/group/leave/v2',
        data: {'id': groupId, 'group_id': groupId},
      );
      final data = response.data;
      return data is Map && data['s'] == true;
    } catch (_) {}
    return false;
  }
}

import '../../core/api/api_client.dart';

class GroupAdminRepository {
  final ApiClient _apiClient;

  GroupAdminRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<bool> updateGroupName(int groupId, String name) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/name',
        data: {'groupID': groupId, 'name': name},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateGroupCategory(int groupId, int categoryId) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/category',
        data: {'groupID': groupId, 'category_id': categoryId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateGroupCapacity(int groupId, int capacity) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/max-member',
        data: {'groupID': groupId, 'maxMember': capacity},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateGroupGoal(int groupId, int goalHours) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/goal-time',
        data: {'groupID': groupId, 'goalTime': goalHours},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateGroupPassword(int groupId, String password) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/password',
        data: {'groupID': groupId, 'password': password},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> promoteGroup(int groupId) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/promote',
        data: {'groupID': groupId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateNotice(int groupId, String notice) async {
    try {
      final response = await _apiClient.post(
        '/group/setting/notice',
        data: {'groupID': groupId, 'notice': notice},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> warnMember(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/warning',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> cancelWarnMember(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/warning/cancel',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> kickMember(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/kick',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> banMember(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/ban',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> unbanMember(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/unban',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchBannedList(int groupId) async {
    try {
      final response = await _apiClient.get(
        '/group/setting/black-list?groupID=$groupId',
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['users'] is List) {
        return (data['users'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> promoteToManager(int groupId, int targetUserId) async {
    try {
      final response = await _apiClient.post(
        '/group/user/manager',
        data: {'groupID': groupId, 'targetUserID': targetUserId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchJoinRequests(int groupId) async {
    try {
      final response = await _apiClient.get(
        '/group/join-requests?groupID=$groupId',
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['requests'] is List) {
        return (data['requests'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> approveRequest(int groupId, int requestId) async {
    try {
      final response = await _apiClient.post(
        '/group/join-request/approve',
        data: {'groupID': groupId, 'requestID': requestId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> rejectRequest(int groupId, int requestId, {String? reason}) async {
    try {
      final response = await _apiClient.post(
        '/group/join-request/reject',
        data: {'groupID': groupId, 'requestID': requestId, 'reason': reason ?? ''},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateChatPermissions(int groupId, bool enabled, int dailyLimit) async {
    try {
      final response = await _apiClient.post(
        '/group/chat/setting',
        data: {
          'groupID': groupId,
          'enabled': enabled,
          'dailyLimit': dailyLimit,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> disbandGroup(int groupId) async {
    try {
      final response = await _apiClient.delete(
        '/group/setting/breakup?groupID=$groupId',
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        return true;
      }
    } catch (_) {}

    try {
      final response = await _apiClient.post(
        '/group/setting/breakup',
        data: {'groupID': groupId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}

    return false;
  }
}

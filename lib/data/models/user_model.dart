import '../../core/utils/json_utils.dart';
import 'group_model.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String statusMessage;
  final String categoryName;
  final int categoryId;
  final int studiconId;
  final String? profilePhotoUrl;
  final String jwtToken;
  final List<GroupModel> userGroups;
  final int flamesBalance;
  final List<int> ownedStudiconIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.statusMessage = '',
    this.categoryName = 'Geral',
    this.categoryId = 0,
    this.studiconId = -1,
    this.profilePhotoUrl,
    required this.jwtToken,
    this.userGroups = const [],
    this.flamesBalance = 100,
    this.ownedStudiconIds = const [],
  });

  String get nickname => name;
  int get avatarStudiconId => studiconId;

  factory UserModel.fromJson(Map<String, dynamic> json, String token) {
    final p = json['p'] is Map<String, dynamic> ? json['p'] as Map<String, dynamic> : null;
    final userId = safeInt(json['id'] ?? json['ud'] ?? json['userId']);
    final rawStudiconId = p?['sd'] ?? p?['ssd'] ?? p?['csd'] ?? json['sd'] ?? json['ssd'] ?? json['csd'] ?? json['studiconId'];
    final int studiconId = (rawStudiconId != null && safeInt(rawStudiconId) > 0)
        ? safeInt(rawStudiconId)
        : -1;
    final hasCustomAvatar = safeBool(json['hasCustomAvatar']);

    final groupsRaw = json['gs'] ?? json['groups'] ?? json['userGroups'];
    final List<GroupModel> groups = (groupsRaw is List)
        ? groupsRaw
            .whereType<Map<String, dynamic>>()
            .map((g) => GroupModel.fromJson(g))
            .toList()
        : const [];

    final scsRaw = json['scs'] ?? json['my'] ?? json['ownedStudiconIds'];
    final List<int> ownedStudicons = [];
    if (scsRaw is List) {
      for (final item in scsRaw) {
        if (item is int) {
          if (item > 0 && !ownedStudicons.contains(item)) ownedStudicons.add(item);
        } else if (item is Map) {
          final id = safeInt(item['id'] ?? item['sc'] ?? item['sd'] ?? item['studiconId']);
          if (id > 0 && !ownedStudicons.contains(id)) ownedStudicons.add(id);
        } else if (item != null) {
          final id = safeInt(item);
          if (id > 0 && !ownedStudicons.contains(id)) ownedStudicons.add(id);
        }
      }
    }

    return UserModel(
      id: userId,
      name: safeString(json['n'] ?? json['name']),
      email: safeString(json['e'] ?? json['email']),
      statusMessage: safeString(json['stm'] ?? json['statusMsg'] ?? p?['stm']),
      categoryName: safeString(json['ct'] ?? json['categoryName']),
      categoryId: safeInt(json['ci'] ?? json['categoryId']),
      studiconId: studiconId,
      profilePhotoUrl: hasCustomAvatar
          ? 'https://alicdn.tgclab.com/user/profile/$userId.jpg'
          : null,
      jwtToken: token,
      userGroups: groups,
      flamesBalance: safeInt(json['fl'] ?? json['flames'] ?? json['flameBalance'], 100),
      ownedStudiconIds: ownedStudicons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'n': name,
      'e': email,
      'stm': statusMessage,
      'ct': categoryName,
      'ci': categoryId,
      'sd': studiconId,
      'studiconId': studiconId,
      'jwtToken': jwtToken,
      'fl': flamesBalance,
      'gs': userGroups.map((g) => g.toJson()).toList(),
      'scs': ownedStudiconIds,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? statusMessage,
    String? categoryName,
    int? categoryId,
    int? studiconId,
    String? profilePhotoUrl,
    String? jwtToken,
    List<GroupModel>? userGroups,
    int? flamesBalance,
    List<int>? ownedStudiconIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      statusMessage: statusMessage ?? this.statusMessage,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      studiconId: studiconId ?? this.studiconId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      jwtToken: jwtToken ?? this.jwtToken,
      userGroups: userGroups ?? this.userGroups,
      flamesBalance: flamesBalance ?? this.flamesBalance,
      ownedStudiconIds: ownedStudiconIds ?? this.ownedStudiconIds,
    );
  }
}

import '../../core/utils/json_utils.dart';

class GroupModel {
  final int id;
  final String name;
  final String category;
  final int dailyGoalHours;
  final int membersCount;
  final int maxCapacity;
  final bool isPrivate;
  final String leaderName;
  final int leaderUserId;
  final String? notice;
  final bool isCamStudy;

  const GroupModel({
    required this.id,
    required this.name,
    required this.category,
    required this.dailyGoalHours,
    required this.membersCount,
    required this.maxCapacity,
    required this.isPrivate,
    required this.leaderName,
    this.leaderUserId = 0,
    this.notice,
    this.isCamStudy = false,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: safeInt(json['id'] ?? json['groupID'] ?? json['gd'] ?? json['gid']),
      name: safeString(json['t'] ?? json['n'] ?? json['name'] ?? json['title'], 'Grupo'),
      category: safeString(json['c'] ?? json['category'] ?? json['ct'], 'Geral'),
      dailyGoalHours: safeInt(json['gt'] ?? json['g'] ?? json['dailyGoalHours'], 8),
      membersCount: safeInt(json['jc'] ?? json['personnel'] ?? json['membersCount'] ?? json['members_count'], 1),
      maxCapacity: safeInt(json['mc'] ?? json['mp'] ?? json['maxPersonnel'] ?? json['maxCapacity'], 50),
      isPrivate: safeBool(json['ip'] ?? json['p'] ?? json['hp'] ?? json['isPrivate']),
      leaderName: safeString(json['on'] ?? json['ln'] ?? json['leader'] ?? json['owner_name']),
      leaderUserId: safeInt(json['od'] ?? json['ou'] ?? json['oid'] ?? json['leaderID'] ?? json['uid'] ?? json['leader_user_id']),
      notice: json['sn'] != null || json['nt'] != null || json['notice'] != null
          ? safeString(json['sn'] ?? json['nt'] ?? json['notice'])
          : null,
      isCamStudy: safeBool(json['cam'] ?? json['isCam'] ?? json['isCamStudy'] ?? json['ic']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'n': name,
      'c': category,
      'gt': dailyGoalHours,
      'jc': membersCount,
      'mp': maxCapacity,
      'ip': isPrivate,
      'on': leaderName,
      'ou': leaderUserId,
      'sn': notice,
      'cam': isCamStudy,
    };
  }
}

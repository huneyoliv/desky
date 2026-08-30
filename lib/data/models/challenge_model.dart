class ChallengeModel {
  final int id;
  final String name;
  final String description;
  final String rules;
  final int flameCost;
  final String checkInMethod;
  final DateTime startDate;
  final DateTime endDate;
  final int checkInCount;
  final double successThreshold;
  final int participantCount;
  final String status;
  final bool isJoined;

  const ChallengeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rules,
    required this.flameCost,
    required this.checkInMethod,
    required this.startDate,
    required this.endDate,
    required this.checkInCount,
    required this.successThreshold,
    required this.participantCount,
    required this.status,
    this.isJoined = false,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? json['n'] ?? 'Desafio de Estudos').toString(),
      description: (json['description'] ?? json['d'] ?? 'Complete a meta diária').toString(),
      rules: (json['rules'] ?? json['r'] ?? 'Estudar ao menos 4 horas por dia durante o período.').toString(),
      flameCost: (json['flame_cost'] ?? json['flameCost'] ?? json['fc'] as num?)?.toInt() ?? 50,
      checkInMethod: (json['checkin_method'] ?? json['method'] ?? 'timer').toString(),
      startDate: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'].toString()) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      checkInCount: (json['checkin_count'] ?? json['cc'] as num?)?.toInt() ?? 0,
      successThreshold: (json['threshold'] as num?)?.toDouble() ?? 0.8,
      participantCount: (json['participants_count'] ?? json['pc'] as num?)?.toInt() ?? 1,
      status: (json['status'] ?? 'active').toString(),
      isJoined: json['is_joined'] as bool? ?? json['joined'] as bool? ?? false,
    );
  }
}

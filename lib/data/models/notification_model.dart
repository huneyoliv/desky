import '../../core/localization/app_translation.dart';
class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// The live API sends uppercase codes with underscores in `nt`
  /// (GROUP_WARNING, GROUP_JOIN_APPROVED, GROUP_OUT, ...). There is no SHAKE
  /// type in the official app, so the raw code is normalised to a small set.
  String get normalizedType {
    final raw = type.trim().toUpperCase();
    if (raw.contains('WARNING')) return 'warning';
    // 'REQUEST'/'WAITING' vem antes de 'JOIN', senao GROUP_JOIN_WAITING cairia
    // no mesmo grupo de "entrada aprovada" e perderia o sentido de pendencia.
    if (raw.contains('REQUEST') || raw.contains('WAITING')) return 'request';
    if (raw.contains('JOIN')) return 'join';
    if (raw.contains('POST') || raw.contains('COMMENT')) return 'post';
    if (raw.contains('NEW_MEMBER')) return 'member';
    if (raw.contains('OUT') || raw.contains('OWNER')) return 'membership';
    return 'info';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawI1 = (json['i1'] ?? json['title'] ?? json['t'] ?? '').toString().trim();
    final rawI2 = (json['i2'] ?? '').toString().trim();
    final rawI3 = (json['i3'] ?? '').toString().trim();
    final rawMsg = (json['content'] ?? json['message'] ?? json['body'] ?? json['m'] ?? '').toString().trim();

    String title;
    String message;

    if (rawI2.isNotEmpty && rawI3.isNotEmpty) {
      title = rawI1.isNotEmpty ? '$rawI1 • $rawI2' : rawI2;
      message = rawI3;
    } else if (rawI1.isNotEmpty && rawI2.isNotEmpty) {
      title = rawI1;
      message = rawI2;
    } else if (rawI1.isNotEmpty && rawMsg.isNotEmpty) {
      title = rawI1;
      message = rawMsg;
    } else if (rawMsg.isNotEmpty) {
      title = rawI1.isNotEmpty ? rawI1 : trMsg('notification_ypt_title', fallback: 'Notificação YPT');
      message = rawMsg;
    } else {
      // The live API fills only `i1` (6/6 items observed), so an invented
      // placeholder would be shown on every notification.
      title = rawI1.isNotEmpty ? rawI1 : trMsg('notification_ypt_title', fallback: 'Notificação YPT');
      message = rawI2;
    }

    final type = (json['nt'] ?? json['type'] ?? json['tp'] ?? 'info').toString();
    final dateStr = json['c'] ?? json['created_at'] ?? json['published_at'];
    final createdAt = dateStr != null ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now() : DateTime.now();
    final isRead = json['ir'] as bool? ?? json['is_read'] as bool? ?? json['read'] as bool? ?? false;

    return NotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead,
    );
  }
}

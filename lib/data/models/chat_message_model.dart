import '../../core/cdn/cdn_resolver.dart';
import '../../core/utils/json_utils.dart';

class ChatMessageModel {
  final int id;
  final int senderId;
  final String senderName;
  final int studiconId;
  final String message;
  final String? photoUrl;
  final String? stickerUrl;
  final String? imageUrl;
  final String? thumbUrl;
  final String type;
  final DateTime sentAt;
  final bool isNotice;
  final Map<String, List<int>> reactions;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.studiconId,
    required this.message,
    this.photoUrl,
    this.stickerUrl,
    this.imageUrl,
    this.thumbUrl,
    this.type = 'text',
    required this.sentAt,
    this.isNotice = false,
    this.reactions = const {},
  });

  String get avatarUrl => CdnResolver.studiconUrl(studiconId, StudiconPose.mini);

  ChatMessageModel copyWith({
    int? id,
    int? senderId,
    String? senderName,
    int? studiconId,
    String? message,
    String? photoUrl,
    String? stickerUrl,
    String? imageUrl,
    String? thumbUrl,
    String? type,
    DateTime? sentAt,
    bool? isNotice,
    Map<String, List<int>>? reactions,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      studiconId: studiconId ?? this.studiconId,
      message: message ?? this.message,
      photoUrl: photoUrl ?? this.photoUrl,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      isNotice: isNotice ?? this.isNotice,
      reactions: reactions ?? this.reactions,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String? photo;
    if (json['photo'] != null && json['photo'].toString().isNotEmpty) {
      photo = CdnResolver.chatPhotoUrl(json['photo'].toString());
    }

    final rawImg = json['img'] as String? ?? json['imageUrl'] as String? ?? photo;
    final rawThumb = json['th'] as String? ?? json['thumbUrl'] as String?;
    final sticker = json['stickerUrl'] as String? ?? json['sticker'] as String?;
    final image = rawImg;
    final msgType = json['type'] as String? ??
        (sticker != null ? 'sticker' : (image != null ? 'image' : 'text'));

    DateTime sentTime = DateTime.now();
    final tsRaw = json['ts'] ?? json['ca'] ?? json['createdAt'];
    if (tsRaw != null) {
      if (tsRaw is num) {
        sentTime = tsRaw > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(tsRaw.toInt())
            : DateTime.fromMillisecondsSinceEpoch((tsRaw * 1000).toInt());
      } else if (tsRaw is String) {
        sentTime = DateTime.tryParse(tsRaw) ?? DateTime.now();
      }
    }

    final reactionsMap = <String, List<int>>{};
    final rawReactions = json['reactions'] ?? json['rc'];
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v is List) {
          reactionsMap[k.toString()] = v.map((e) => safeInt(e)).toList();
        }
      });
    }

    return ChatMessageModel(
      id: safeInt(json['idx'] ?? json['id'], DateTime.now().millisecondsSinceEpoch),
      senderId: safeInt(json['uid'] ?? json['ud']),
      senderName: safeString(json['nn'] ?? json['n'], 'Usuário'),
      studiconId: safeInt(json['sd'] ?? json['did'] ?? json['st'] ?? json['si'], -1),
      message: safeString(json['msg'] ?? json['m'] ?? json['text']),
      photoUrl: photo,
      stickerUrl: sticker,
      imageUrl: image,
      thumbUrl: rawThumb,
      type: msgType,
      sentAt: sentTime,
      isNotice: safeBool(json['isNotice'] ?? json['sn']),
      reactions: reactionsMap,
    );
  }
}

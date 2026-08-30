import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/sticker_model.dart';

class ChatMediaRepository {
  final ApiClient _apiClient;

  ChatMediaRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<StickerSet>> fetchStickerSets() async {
    try {
      final response = await _apiClient.get('/chat/sticker/sets');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['sets'] ?? data['s'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => StickerSet.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Sticker>> fetchStickers(int setId) async {
    try {
      final response = await _apiClient.get('/chat/stickers?setId=$setId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['stickers'] ?? data['s'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => Sticker.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<String?> uploadChatImage({
    required int groupId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
        ),
        'groupID': groupId,
        'type': 'chat',
      });

      final response = await _apiClient.post(
        ApiConstants.uploadUrl,
        data: formData,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final path = data['url'] ?? data['path'] ?? data['file'];
        if (path != null) {
          final relative = path.toString();
          if (relative.startsWith('http')) return relative;
          return '${ApiConstants.mediaCdnUrl}$relative';
        }
      }
    } catch (_) {}
    return null;
  }
}

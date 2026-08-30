import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';

class CamUploadRepository {
  final ApiClient _apiClient;

  CamUploadRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<String?> uploadCamPhoto({
    required int groupId,
    required Uint8List imageBytes,
    required String dateYmd,
    required int userId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'cam_${groupId}_$userId.jpg',
        ),
        'groupID': groupId,
        'userID': userId,
        'date': dateYmd,
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

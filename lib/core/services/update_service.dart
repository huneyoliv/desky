import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/updates/models/update_model.dart';
import '../../features/updates/update_channel.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

class UpdateService {
  final Dio _dio;
  static const String latestReleaseUrl =
      'https://api.github.com/repos/huneyoliv/desky/releases/latest';

  /// First page of the release list instead of "latest", because GitHub's
  /// `/releases/latest` excludes pre-releases and drafts entirely.
  static const String releasesListUrl =
      'https://api.github.com/repos/huneyoliv/desky/releases?per_page=30';

  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Accept': 'application/vnd.github.v3+json',
                  'User-Agent': 'Desky-App',
                },
              ),
            );

  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        latestReleaseUrl,
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return AppRelease.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Retorna null silenciosamente em caso de erro de rede ou 404 sem quebrar o app
    }
    return null;
  }

  /// Release to offer for the given channel.
  ///
  /// Stable keeps using `/releases/latest` (a superset check is not needed and
  /// it is one request). Beta reads the first page of `/releases`, drops drafts,
  /// accepts pre-releases and returns the highest by SemVer.
  Future<AppRelease?> fetchReleaseForChannel({
    required bool betaChannel,
    CancelToken? cancelToken,
  }) async {
    if (!betaChannel) {
      return fetchLatestRelease(cancelToken: cancelToken);
    }
    try {
      final response = await _dio.get(
        releasesListUrl,
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200 && response.data is List) {
        return UpdateChannel.fromReleaseList(response.data as List<dynamic>);
      }
    } catch (_) {
      // Rede/limite de taxa: cai para o caminho estavel em vez de falhar.
      return fetchLatestRelease(cancelToken: cancelToken);
    }
    return null;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:desky/features/updates/update_channel.dart';

Map<String, dynamic> _release(
  String tag, {
  bool draft = false,
  bool prerelease = false,
  String body = '',
}) {
  return {
    'id': tag.hashCode,
    'tag_name': tag,
    'name': tag,
    'body': body,
    'html_url': 'https://github.com/huneyoliv/desky/releases/tag/$tag',
    'published_at': '2026-11-14T10:00:00Z',
    'prerelease': prerelease,
    'draft': draft,
    'assets': [
      {
        'id': 1,
        'name': 'Desky-Windows-Installer-x64.exe',
        'size': 100,
        'browser_download_url': 'https://github.com/a.exe',
        'content_type': 'application/x-msdownload',
      },
    ],
  };
}

/// Dio that answers with a canned payload, so the channel routing can be
/// asserted without touching the network.
class _StubDio implements Dio {
  _StubDio({required this.onGet});

  final Future<Response<dynamic>> Function(String path) onGet;
  final List<String> requestedPaths = [];

  @override
  Future<Response<T>> get<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestedPaths.add(url);
    final response = await onGet(url);
    return Response<T>(
      requestOptions: RequestOptions(path: url),
      data: response.data as T?,
      statusCode: response.statusCode,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('UpdateChannel.best', () {
    test('escolhe a maior versao por semver, nao a primeira da lista', () {
      final releases = [
        AppRelease.fromJson(_release('v1.1.7')),
        AppRelease.fromJson(_release('v1.2.0-beta.2', prerelease: true)),
        AppRelease.fromJson(_release('v1.2.0-beta.1', prerelease: true)),
        AppRelease.fromJson(_release('v1.1.6')),
      ];

      final best = UpdateChannel.best(releases: releases);

      expect(best, isNotNull);
      expect(best!.cleanVersion, equals('1.2.0-beta.2'));
    });

    test('ignora drafts', () {
      final releases = [
        AppRelease.fromJson(_release('v1.2.0', draft: true)),
        AppRelease.fromJson(_release('v1.1.7')),
      ];

      final best = UpdateChannel.best(releases: releases);

      expect(best!.cleanVersion, equals('1.1.7'));
    });

    test('aceita pre-release por padrao', () {
      final releases = [
        AppRelease.fromJson(_release('v1.2.0-beta.1', prerelease: true)),
        AppRelease.fromJson(_release('v1.1.7')),
      ];

      expect(UpdateChannel.best(releases: releases)!.cleanVersion,
          equals('1.2.0-beta.1'));
    });

    test('pode excluir pre-releases quando pedido', () {
      final releases = [
        AppRelease.fromJson(_release('v1.2.0-beta.1', prerelease: true)),
        AppRelease.fromJson(_release('v1.1.7')),
      ];

      expect(
        UpdateChannel.best(releases: releases, includePreReleases: false)!.cleanVersion,
        equals('1.1.7'),
      );
    });

    test('prefere a final sobre a rc da mesma base', () {
      final releases = [
        AppRelease.fromJson(_release('v1.2.0-rc.1', prerelease: true)),
        AppRelease.fromJson(_release('v1.2.0')),
      ];

      expect(UpdateChannel.best(releases: releases)!.cleanVersion, equals('1.2.0'));
    });

    test('lista vazia ou sem versao legivel devolve null', () {
      expect(UpdateChannel.best(releases: const []), isNull);
      expect(
        UpdateChannel.best(releases: [
          AppRelease.fromJson(_release('nao-e-versao')),
          AppRelease.fromJson(_release('x.y.z', draft: true)),
        ]),
        isNull,
      );
    });
  });

  group('UpdateChannel.fromReleaseList', () {
    test('le o payload cru do GitHub e filtra o que nao presta', () {
      final payload = <dynamic>[
        _release('v1.2.0-beta.1', prerelease: true),
        _release('v1.3.0', draft: true),
        'lixo',
        {'tag_name': 'sem-numeros'},
        _release('v1.2.0-beta.2', prerelease: true),
      ];

      final best = UpdateChannel.fromReleaseList(payload);

      expect(best!.cleanVersion, equals('1.2.0-beta.2'));
    });
  });

  group('UpdateChannel.defaultEnabledFor', () {
    test('liga por padrao so quando o build e pre-lancamento', () {
      expect(UpdateChannel.defaultEnabledFor('1.2.0-beta.1'), isTrue);
      expect(UpdateChannel.defaultEnabledFor('1.2.0-rc.1'), isTrue);
      expect(UpdateChannel.defaultEnabledFor('1.2.0'), isFalse);
      expect(UpdateChannel.defaultEnabledFor('1.1.7+18'), isFalse);
      expect(UpdateChannel.defaultEnabledFor('lixo'), isFalse);
    });
  });

  group('UpdateService.fetchReleaseForChannel', () {
    test('canal estavel usa /releases/latest', () async {
      final dio = _StubDio(
        onGet: (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: _release('v1.1.7'),
          statusCode: 200,
        ),
      );
      final service = UpdateService(dio: dio);

      final release =
          await service.fetchReleaseForChannel(betaChannel: false);

      expect(release!.cleanVersion, equals('1.1.7'));
      expect(dio.requestedPaths.single, contains('/releases/latest'));
    });

    test('canal beta usa /releases e escolhe a maior', () async {
      final dio = _StubDio(
        onGet: (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: [
            _release('v1.1.7'),
            _release('v1.2.0-beta.1', prerelease: true),
            _release('v1.2.0-beta.3', prerelease: true),
          ],
          statusCode: 200,
        ),
      );
      final service = UpdateService(dio: dio);

      final release = await service.fetchReleaseForChannel(betaChannel: true);

      expect(release!.cleanVersion, equals('1.2.0-beta.3'));
      expect(dio.requestedPaths.single, contains('/releases?'));
      expect(dio.requestedPaths.single, isNot(contains('/releases/latest')));
    });

    test('canal beta com lista vazia devolve null sem quebrar', () async {
      final dio = _StubDio(
        onGet: (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: const <dynamic>[],
          statusCode: 200,
        ),
      );
      final service = UpdateService(dio: dio);

      expect(await service.fetchReleaseForChannel(betaChannel: true), isNull);
    });

    test('falha de rede no beta cai para /releases/latest', () async {
      final dio = _StubDio(
        onGet: (path) async {
          if (path.contains('/releases?')) {
            throw DioException.connectionError(
              requestOptions: RequestOptions(path: path),
              reason: 'sem rede',
            );
          }
          return Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            data: _release('v1.1.7'),
            statusCode: 200,
          );
        },
      );
      final service = UpdateService(dio: dio);

      final release = await service.fetchReleaseForChannel(betaChannel: true);

      expect(release!.cleanVersion, equals('1.1.7'));
      expect(dio.requestedPaths.any((p) => p.contains('/releases/latest')), isTrue);
    });
  });
}
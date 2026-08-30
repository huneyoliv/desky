import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responseData;
  final int statusCode;

  MockHttpClientAdapter({
    required this.responseData,
    this.statusCode = 200,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      Dio().transformer.transformResponse(options, ResponseBody.fromString(
        responseData.toString(),
        statusCode,
      )).toString(),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeApiClient extends ApiClient {
  final Map<String, dynamic> fakeResponse;

  FakeApiClient(this.fakeResponse);

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      data: fakeResponse,
      statusCode: 200,
      requestOptions: RequestOptions(path: path, data: data),
    );
  }
}

void main() {
  group('SubjectRepository', () {
    test('createSubject parses response correctly with sb key (matching HAR API)', () async {
      final fakeApiClient = FakeApiClient({
        's': true,
        'sb': {
          'id': 129534517,
          'tt': 'Teste',
          'sm': 0,
          'or': 100,
          'co': 4284513675,
          'ia': false,
        },
        'ss': [],
        'pv': 53,
      });

      final repository = SubjectRepository(apiClient: fakeApiClient);
      final subject = await repository.createSubject(
        title: 'Teste',
        colorInt: 4284513675,
      );

      expect(subject.id, equals(129534517));
      expect(subject.title, equals('Teste'));
      expect(subject.colorInt, equals(4284513675));
      expect(subject.isArchived, isFalse);
    });

    test('updateSubject sends correct payload and returns true on success', () async {
      final fakeApiClient = FakeApiClient({
        's': true,
        'ss': [
          {
            'id': 129534517,
            'tt': 'Teste1',
            'sm': 0,
            'or': 100,
            'co': 4284513675,
            'dl': false,
            'ia': false,
          }
        ],
        'pv': 56,
      });

      final repository = SubjectRepository(apiClient: fakeApiClient);
      const model = SubjectModel(
        id: 129534517,
        title: 'Teste1',
        colorInt: 4284513675,
        isArchived: false,
      );
      final success = await repository.updateSubject(model);

      expect(success, isTrue);
    });

    test('archiveSubject sends correct payload and returns true on success', () async {
      final fakeApiClient = FakeApiClient({
        's': true,
        'pv': 54,
      });

      final repository = SubjectRepository(apiClient: fakeApiClient);
      final success = await repository.archiveSubject(129534517, true);

      expect(success, isTrue);
    });

    test('deleteSubject sends correct payload and returns true on success', () async {
      final fakeApiClient = FakeApiClient({
        's': true,
        'pv': 57,
      });

      final repository = SubjectRepository(apiClient: fakeApiClient);
      final success = await repository.deleteSubject(129534517);

      expect(success, isTrue);
    });
  });
}

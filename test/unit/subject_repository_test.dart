import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? postResponse;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('SubjectRepository Tests', () {
    late MockApiClient mockApiClient;
    late SubjectRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = SubjectRepository(apiClient: mockApiClient);
    });

    test('createSubject sends POST to subject create endpoint and returns SubjectModel', () async {
      mockApiClient.postResponse = {
        's': true,
        'subject': {
          'id': 201,
          'tt': 'História do Brasil',
          'sm': 0,
          'or': 1,
          'co': 4292557552,
        }
      };

      final subject = await repository.createSubject(
        title: 'História do Brasil',
        colorInt: 4292557552,
      );

      expect(subject.id, equals(201));
      expect(subject.title, equals('História do Brasil'));
    });

    test('fetchSubjects parses splash response with subjects and study times', () async {
      mockApiClient.postResponse = {
        'ss': [
          {
            'id': 101,
            'tt': 'Química Orgânica',
            'sm': 1800000,
            'or': 1,
            'co': 4292557552,
            'dl': false,
          },
        ],
        'dl': {
          'sm': 3600000,
          'ls': [
            {'sb': 'Química Orgânica', 'sm': 3600000},
          ]
        }
      };

      final result = await repository.fetchSubjectsData();
      expect(result.subjects.length, equals(1));
      expect(result.subjects.first.title, equals('Química Orgânica'));
      expect(result.subjects.first.studyMs, equals(3600000));
      expect(result.todayTotalMs, equals(3600000));
    });

    test('updateSubject sends POST and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      const subject = SubjectModel(
        id: 101,
        title: 'Química Geral',
        colorInt: 4292557552,
      );

      final success = await repository.updateSubject(subject);
      expect(success, isTrue);
    });

    test('deleteSubject sends POST and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.deleteSubject(101);
      expect(success, isTrue);
    });

    test('archiveSubject sends POST and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.archiveSubject(101, true);
      expect(success, isTrue);
    });

    test('reorderSubjects sends orders list to backend', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.reorderSubjects([101, 102, 103]);
      expect(success, isTrue);
    });
  });
}

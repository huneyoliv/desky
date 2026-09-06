import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      SharedPreferences.setMockInitialValues({});
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
          {
            'id': 102,
            'tt': 'Física Quântica',
            'sm': 7200000, // weekly accumulated time
            'or': 2,
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
      expect(result.subjects.length, equals(2));
      // Studied today: uses today's time
      expect(result.subjects[0].title, equals('Química Orgânica'));
      expect(result.subjects[0].studyMs, equals(3600000));
      // Not studied today: should be 0ms, NOT weekly accumulated total (7200000)
      expect(result.subjects[1].title, equals('Física Quântica'));
      expect(result.subjects[1].studyMs, equals(0));
      expect(result.todayTotalMs, equals(3600000));
    });

    test('fetchSubjects handles null dl gracefully setting 0ms for all subjects', () async {
      mockApiClient.postResponse = {
        'ss': [
          {
            'id': 101,
            'tt': 'Matemática',
            'sm': 5400000, // weekly accumulated time
            'or': 1,
            'co': 4292557552,
            'dl': false,
          },
        ],
        'dl': null,
      };

      final result = await repository.fetchSubjectsData();
      expect(result.subjects.length, equals(1));
      expect(result.subjects.first.title, equals('Matemática'));
      expect(result.subjects.first.studyMs, equals(0));
      expect(result.todayTotalMs, equals(0));
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

    test('cacheSubjects and getCachedSubjects persist and retrieve subjects', () async {
      const list = [
        SubjectModel(id: 301, title: 'Direito Constitucional', colorInt: 4284513675),
        SubjectModel(id: 302, title: 'Direito Administrativo', colorInt: 4292557552),
      ];
      await repository.cacheSubjects(list);
      final retrieved = await repository.getCachedSubjects();
      expect(retrieved.length, equals(2));
      expect(retrieved[0].title, equals('Direito Constitucional'));
      expect(retrieved[1].title, equals('Direito Administrativo'));
    });

    test('saveSubjectsFromRawData extracts subjects from login response and caches them', () async {
      final loginResponse = {
        's': true,
        'jwt': 'sample.jwt.token',
        'ss': [
          {'id': 401, 'tt': 'Biologia Molecular', 'co': 4284513675, 'dl': false},
          {'id': 402, 'tt': 'Genética', 'co': 4292557552, 'dl': false},
        ],
      };
      await SubjectRepository.saveSubjectsFromRawData(loginResponse);
      final cached = await repository.getCachedSubjects();
      expect(cached.length, equals(2));
      expect(cached[0].title, equals('Biologia Molecular'));
      expect(cached[1].title, equals('Genética'));
    });

    test('fetchSubjectsData falls back to cached subjects when API returns empty list', () async {
      const cachedList = [
        SubjectModel(id: 501, title: 'Cálculo I', colorInt: 4284513675),
      ];
      await repository.cacheSubjects(cachedList);

      mockApiClient.postResponse = {'s': true, 'ss': []};
      final result = await repository.fetchSubjectsData();
      expect(result.subjects.length, equals(1));
      expect(result.subjects.first.title, equals('Cálculo I'));
    });
  });
}

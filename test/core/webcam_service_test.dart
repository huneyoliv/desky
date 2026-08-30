import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/services/webcam_service.dart';
import 'package:desky/data/repositories/cam_upload_repository.dart';

class MockCamUploadRepository extends CamUploadRepository {
  int uploadCallCount = 0;

  @override
  Future<String?> uploadCamPhoto({
    required int groupId,
    required Uint8List imageBytes,
    required String dateYmd,
    required int userId,
  }) async {
    uploadCallCount++;
    return 'https://alicdn.tgclab.com/cam/$dateYmd/$userId';
  }
}

void main() {
  group('WebcamService Tests', () {
    late MockCamUploadRepository mockRepo;
    late WebcamService service;

    setUp(() {
      mockRepo = MockCamUploadRepository();
      service = WebcamService(camUploadRepository: mockRepo);
    });

    tearDown(() {
      service.dispose();
    });

    test('startPeriodicCapture sets isCapturing true and triggers upload', () async {
      service.startPeriodicCapture(
        groupId: 1,
        userId: 100,
        interval: const Duration(milliseconds: 100),
      );

      expect(service.isCapturing, isTrue);
      expect(mockRepo.uploadCallCount, 1);
      expect(service.lastFrame, isNotNull);
    });

    test('stopCapture cancels timer and sets isCapturing false', () async {
      service.startPeriodicCapture(
        groupId: 1,
        userId: 100,
        interval: const Duration(milliseconds: 100),
      );

      service.stopCapture();

      expect(service.isCapturing, isFalse);
    });
  });
}

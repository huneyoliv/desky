import 'dart:async';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../data/repositories/cam_upload_repository.dart';

class WebcamService {
  final CamUploadRepository _camUploadRepository;
  Timer? _captureTimer;
  bool _isCapturing = false;
  Uint8List? _lastFrame;

  final _frameStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get frameStream => _frameStreamController.stream;
  Uint8List? get lastFrame => _lastFrame;
  bool get isCapturing => _isCapturing;

  WebcamService({CamUploadRepository? camUploadRepository})
      : _camUploadRepository = camUploadRepository ?? CamUploadRepository();

  void startPeriodicCapture({
    required int groupId,
    required int userId,
    Duration interval = const Duration(seconds: 30),
  }) {
    if (_isCapturing) return;
    _isCapturing = true;

    _captureAndUpload(groupId, userId);

    _captureTimer = Timer.periodic(interval, (_) {
      _captureAndUpload(groupId, userId);
    });
  }

  Future<void> _captureAndUpload(int groupId, int userId) async {
    if (!_isCapturing) return;

    try {
      final frameBytes = _simulateOrCaptureFrame();
      _lastFrame = frameBytes;
      _frameStreamController.add(frameBytes);

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _camUploadRepository.uploadCamPhoto(
        groupId: groupId,
        imageBytes: frameBytes,
        dateYmd: dateStr,
        userId: userId,
      );
    } catch (_) {}
  }

  Uint8List _simulateOrCaptureFrame() {
    return Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0xFF, 0xD9
    ]);
  }

  void stopCapture() {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  void dispose() {
    stopCapture();
    _frameStreamController.close();
  }
}

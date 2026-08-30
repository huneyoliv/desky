import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/oauth/qr_auth_service.dart';

void main() {
  group('QrAuthService Tests', () {
    late QrAuthService service;
    final dio = Dio();

    setUp(() {
      service = QrAuthService();
    });

    tearDown(() async {
      await service.cancel();
    });

    test('getLocalIpAddress returns valid non-empty IP string', () async {
      final ip = await service.getLocalIpAddress();
      expect(ip.isNotEmpty, isTrue);
      expect(ip.contains('.'), isTrue);
    });

    test('getAvailableIpAddresses returns list of LAN interfaces with valid IPs', () async {
      final ips = await service.getAvailableIpAddresses();
      expect(ips.isNotEmpty, isTrue);
      expect(ips.first.ip.isNotEmpty, isTrue);
      expect(ips.first.name.isNotEmpty, isTrue);
    });

    test('copyWithIp updates hostIp and pairingUrl accurately', () async {
      final session = await service.startSession();
      session.tokenFuture.ignore();
      final updated = session.copyWithIp('192.168.1.100');
      expect(updated.hostIp, equals('192.168.1.100'));
      expect(updated.pairingUrl, contains('192.168.1.100:${session.port}'));
    });

    test('startSession binds local server and exposes pairingUrl with valid session token', () async {
      final session = await service.startSession(
        timeout: const Duration(seconds: 10),
      );
      session.tokenFuture.ignore();

      expect(session.sessionId.isNotEmpty, isTrue);
      expect(session.sessionId.length, greaterThanOrEqualTo(32));
      expect(session.port, greaterThan(0));
      expect(session.pairingUrl, contains('/pair?session=${session.sessionId}'));
    });

    test('HTTP GET /pair returns 200 with valid session and 401 with invalid session', () async {
      final session = await service.startSession(
        timeout: const Duration(seconds: 10),
      );
      session.tokenFuture.ignore();

      final validRes = await dio.get(
        'http://127.0.0.1:${session.port}/pair?session=${session.sessionId}',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      expect(validRes.statusCode, equals(200));
      expect(validRes.data.toString(), contains('Desky Companion'));

      final invalidRes = await dio.get(
        'http://127.0.0.1:${session.port}/pair?session=invalid_session_123',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      expect(invalidRes.statusCode, equals(401));
      expect(invalidRes.data.toString(), contains('Sessão Expirada ou Inválida'));
    });

    test('HTTP POST /api/pair completes future on valid session and token', () async {
      final session = await service.startSession(
        timeout: const Duration(seconds: 10),
      );

      final postRes = await dio.post(
        'http://127.0.0.1:${session.port}/api/pair',
        data: {
          'session': session.sessionId,
          'jwt': 'fake_mobile_jwt_token_999',
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      expect(postRes.statusCode, equals(200));
      expect(postRes.data['s'], isTrue);

      final receivedToken = await session.tokenFuture;
      expect(receivedToken, equals('fake_mobile_jwt_token_999'));
    });

    test('HTTP POST /api/pair returns 400 on mismatched session or empty token', () async {
      final session = await service.startSession(
        timeout: const Duration(seconds: 10),
      );
      session.tokenFuture.ignore();

      final postRes = await dio.post(
        'http://127.0.0.1:${session.port}/api/pair',
        data: {
          'session': 'wrong_session_id',
          'jwt': 'token_abc',
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      expect(postRes.statusCode, equals(400));
      expect(postRes.data['s'], isFalse);
    });

    test('cancel terminates server and cancels session future', () async {
      final session = await service.startSession(
        timeout: const Duration(seconds: 10),
      );

      final futureExpectation = expectLater(session.tokenFuture, throwsA(anything));
      await service.cancel();
      await futureExpectation;
    });
  });
}

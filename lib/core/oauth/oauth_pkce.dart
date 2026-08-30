import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class OAuthPkce {
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String generateVerifier([int length = 64]) {
    final random = Random.secure();
    return List.generate(length, (_) => _charset[random.nextInt(_charset.length)])
        .join();
  }

  static String generateChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String generateState([int length = 32]) {
    final random = Random.secure();
    return List.generate(length, (_) => _charset[random.nextInt(_charset.length)])
        .join();
  }

  static Map<String, dynamic> decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      throw const FormatException('Token JWT inválido: estrutura incorreta');
    }
    var payload = parts[1];
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    final normalized = base64Url.normalize(payload);
    final bytes = base64Url.decode(normalized);
    final decodedString = utf8.decode(bytes);
    final json = jsonDecode(decodedString);
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw const FormatException('Payload JWT não é um objeto JSON válido');
  }
}

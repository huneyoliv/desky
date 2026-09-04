import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/auth_interceptor.dart';
import '../../core/constants/api_constants.dart';
import '../../core/oauth/social_signup_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  static const String keyCachedUser = 'cached_user_profile';
  static const String keyUserEquippedStudiconId = 'user_equipped_studicon_id';

  AuthRepository({
    ApiClient? apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> _saveToken(String token) async {
    try {
      await _storage.write(key: AuthInterceptor.keyJwtToken, value: token);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthInterceptor.keyJwtToken, token);
    } catch (_) {}
  }

  Future<void> _deleteToken() async {
    try {
      await _storage.delete(key: AuthInterceptor.keyJwtToken);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AuthInterceptor.keyJwtToken);
      await prefs.remove(keyCachedUser);
      await prefs.remove(keyUserEquippedStudiconId);
    } catch (_) {}
  }

  Future<void> _cacheUserData(Map<String, dynamic> data, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = UserModel.fromJson(data, token);
      await prefs.setString(keyCachedUser, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
    String language = ApiConstants.defaultLanguage,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.signInJwt,
      data: {
        'email': email,
        'password': password,
        'loginProvider': 'Email',
        'new': true,
        'getx': true,
        'language': language,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic> || data['s'] != true) {
      String msg = 'E-mail ou senha incorretos';
      if (data is Map) {
        if (data['m'] != null || data['message'] != null) {
          msg = (data['m'] ?? data['message']).toString();
        } else if (data['c'] != null) {
          final code = data['c'].toString();
          if (code == '112') {
            msg = 'Senha incorreta. Verifique sua senha e tente novamente.';
          } else if (code == '113') {
            msg = 'E-mail não cadastrado no Yeolpumta.';
          } else if (code == '114') {
            msg = 'Conta suspensa ou inativa.';
          } else {
            msg = 'Falha na autenticação (código $code)';
          }
        }
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }

    final token = (data['jwt'] ?? '').toString();
    if (token.isEmpty) {
      throw const ApiException('Token JWT não foi retornado pelo servidor');
    }

    await _saveToken(token);

    try {
      final splashData = await splashLogin(language: language);
      if (splashData != null) {
        if (splashData['gs'] != null) data['gs'] = splashData['gs'];
        if (splashData['scs'] != null) data['scs'] = splashData['scs'];
        if (splashData['fl'] != null) data['fl'] = splashData['fl'];
        if (splashData['sd'] != null) data['sd'] = splashData['sd'];
        if (splashData['p'] is Map) {
          final p = splashData['p'] as Map;
          if (p['sd'] != null) data['sd'] = p['sd'];
          if (p['ssd'] != null) data['ssd'] = p['ssd'];
          if (p['csd'] != null) data['csd'] = p['csd'];
        }
      }
    } catch (_) {}

    await _cacheUserData(data, token);
    return UserModel.fromJson(data, token);
  }

  Future<bool> checkUsernameExists(String username) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.existUsername,
        data: {'username': username},
      );
      final data = response.data;
      if (data is Map) {
        return data['s'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel> signInWithSocial({
    required String provider, // "Google", "Apple", "Kakao", "Naver"
    required String socialId,
    required String email,
    required String name,
    String language = ApiConstants.defaultLanguage,
  }) async {
    final String formattedProviderId = switch (provider.toLowerCase()) {
      'google' => socialId.startsWith('g') ? socialId : 'g$socialId',
      'apple' => socialId.startsWith('a') ? socialId : 'a$socialId',
      'kakao' => socialId.startsWith('k') ? socialId : 'k$socialId',
      'naver' => socialId.startsWith('n') ? socialId : 'n$socialId',
      _ => socialId,
    };

    final payload = {
      'accessToken': '',
      'providerId': formattedProviderId,
      'email': email,
      'loginProvider': provider,
      'new': true,
      'getx': true,
      'version': ApiConstants.defaultVersion,
      'language': language,
    };
    final response = await _apiClient.post(
      ApiConstants.socialSignUpJwt,
      data: payload,
    );

    final data = response.data;
    if (data is! Map<String, dynamic> || data['s'] != true) {
      if (data is Map) {
        final code = data['c']?.toString();
        if (code == '111' || code == '113') {
          throw SocialSignUpRequiredException(
            provider: provider,
            socialId: socialId,
            email: email,
            name: name,
          );
        }
        final msg = data['m']?.toString() ??
            data['message']?.toString() ??
            (code != null ? 'Erro de autenticação [$code]' : 'Falha ao autenticar via $provider');
        throw ApiException(msg, statusCode: response.statusCode);
      }
      throw ApiException('Falha ao autenticar via $provider', statusCode: response.statusCode);
    }

    final token = (data['jwt'] ?? '').toString();
    if (token.isEmpty) {
      throw ApiException('Token JWT via $provider não retornado pelo servidor');
    }

    await _saveToken(token);

    try {
      final splashData = await splashLogin(language: language);
      if (splashData != null) {
        if (splashData['gs'] != null) data['gs'] = splashData['gs'];
        if (splashData['scs'] != null) data['scs'] = splashData['scs'];
        if (splashData['fl'] != null) data['fl'] = splashData['fl'];
        if (splashData['sd'] != null) data['sd'] = splashData['sd'];
        if (splashData['p'] is Map) {
          final p = splashData['p'] as Map;
          if (p['sd'] != null) data['sd'] = p['sd'];
          if (p['ssd'] != null) data['ssd'] = p['ssd'];
          if (p['csd'] != null) data['csd'] = p['csd'];
        }
      }
    } catch (_) {}

    await _cacheUserData(data, token);
    return UserModel.fromJson(data, token);
  }

  Future<UserModel> signUpWithSocial({
    required String provider,
    required String socialId,
    required String email,
    required String name,
    required String nickname,
    required int countryId,
    required int categoryId,
    String language = ApiConstants.defaultLanguage,
  }) async {
    final String formattedProviderId = switch (provider.toLowerCase()) {
      'google' => socialId.startsWith('g') ? socialId : 'g$socialId',
      'apple' => socialId.startsWith('a') ? socialId : 'a$socialId',
      'kakao' => socialId.startsWith('k') ? socialId : 'k$socialId',
      'naver' => socialId.startsWith('n') ? socialId : 'n$socialId',
      _ => socialId,
    };

    final payload = {
      'accessToken': '',
      'providerId': formattedProviderId,
      'email': email,
      'loginProvider': provider,
      'nickname': nickname,
      'countryId': countryId,
      'categoryId': categoryId,
      'new': true,
      'getx': true,
      'version': ApiConstants.defaultVersion,
      'language': language,
    };
    final response = await _apiClient.post(
      ApiConstants.socialSignUpJwt,
      data: payload,
    );

    final data = response.data;
    if (data is! Map<String, dynamic> || data['s'] != true) {
      String msg;
      if (data is Map) {
        final code = data['c']?.toString();
        if (code == '104') {
          msg = 'Este apelido já está em uso. Insira outro apelido.';
        } else if (code == '103' || code == '116') {
          msg = 'Não é possível usar este apelido. Insira outro apelido.';
        } else {
          msg = data['m']?.toString() ??
              data['message']?.toString() ??
              (code != null ? 'Erro de cadastro [$code]' : 'Falha ao cadastrar via $provider');
        }
      } else {
        msg = 'Falha ao cadastrar via $provider';
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }

    final token = (data['jwt'] ?? '').toString();
    if (token.isEmpty) {
      throw ApiException('Token JWT via $provider não retornado pelo servidor');
    }

    await _saveToken(token);

    if (nickname.isNotEmpty) {
      try {
        final nickRes = await _apiClient.post(
          ApiConstants.nicknameChange,
          data: {'nickname': nickname},
        );
        final nickData = nickRes.data;
        if (nickData is Map && nickData['s'] == false) {
          final nc = nickData['c']?.toString();
          if (nc == '104') {
            throw const ApiException('Este apelido já está em uso. Insira outro apelido.');
          } else if (nc == '103' || nc == '116') {
            throw const ApiException('Não é possível usar este apelido. Insira outro apelido.');
          }
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }

    if (categoryId > 0) {
      try {
        await _apiClient.post(
          ApiConstants.categoryByCountry,
          data: {'category_id': categoryId},
        );
      } catch (_) {}
    }

    try {
      final splashData = await splashLogin(language: language);
      if (splashData != null) {
        if (splashData['gs'] != null) data['gs'] = splashData['gs'];
        if (splashData['scs'] != null) data['scs'] = splashData['scs'];
        if (splashData['fl'] != null) data['fl'] = splashData['fl'];
        if (splashData['sd'] != null) data['sd'] = splashData['sd'];
        if (splashData['p'] is Map) {
          final p = splashData['p'] as Map;
          if (p['sd'] != null) data['sd'] = p['sd'];
          if (p['ssd'] != null) data['ssd'] = p['ssd'];
          if (p['csd'] != null) data['csd'] = p['csd'];
        }
      }
    } catch (_) {}

    await _cacheUserData(data, token);
    return UserModel.fromJson(data, token);
  }

  Future<UserModel> signInWithJwt(String token, {String language = ApiConstants.defaultLanguage}) async {
    final cleanToken = token.trim().replaceAll('JWT ', '').replaceAll('Bearer ', '');
    if (cleanToken.isEmpty) {
      throw const ApiException('Token JWT não fornecido.');
    }

    await _saveToken(cleanToken);

    final splashData = await splashLogin(language: language);
    if (splashData == null || splashData['s'] != true) {
      await _deleteToken();
      throw const ApiException('Sessão inválida ou expirada no servidor.');
    }

    await _cacheUserData(splashData, cleanToken);
    return UserModel.fromJson(splashData, cleanToken);
  }

  Future<Map<String, dynamic>?> splashLogin({
    String language = ApiConstants.defaultLanguage,
    String timezone = ApiConstants.defaultTimezone,
    int version = ApiConstants.defaultVersion,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.splashLogin,
        data: {
          'version': version,
          'pushToken': '',
          'timezone': timezone,
          'deviceType': ApiConstants.defaultDeviceType,
          'osVersion': 10,
          'deviceModel': ApiConstants.defaultDeviceModel,
          'pv': 2,
          'language': language,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> changeNickname(String nickname) async {
    try {
      final response = await _apiClient.post(
        '/user/nickname/change',
        data: {'nickname': nickname},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> changeStatusMessage(String statusMsg) async {
    try {
      final response = await _apiClient.post(
        '/user/status_msg/change',
        data: {'statusMsg': statusMsg},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> changeCategory(int categoryId) async {
    try {
      final response = await _apiClient.post(
        '/user/category/change',
        data: {'category_id': categoryId, 'categoryId': categoryId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> sendPasswordResetCode(
    String email, {
    String language = ApiConstants.defaultLanguage,
  }) async {
    final response = await _apiClient.post(
      '/user/v2/send-password-reset-code',
      data: {
        'email': email,
        'language': language,
      },
    );
    final data = response.data;
    return data is Map<String, dynamic> && data['s'] == true;
  }

  Future<bool> verifyPasswordResetCode(String email, String code) async {
    final response = await _apiClient.post(
      '/user/v2/verify-code',
      data: {
        'email': email,
        'code': code,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == false) {
      final msg = data['c'] == 'invalid_auth_code_msg'
          ? 'Código de validação inválido'
          : 'Código incorreto';
      throw ApiException(msg);
    }
    return data is Map<String, dynamic> && data['s'] == true;
  }

  Future<UserModel> resetPassword({
    required String email,
    required String password,
    required String code,
  }) async {
    final response = await _apiClient.post(
      '/user/v2/reset-password',
      data: {
        'email': email,
        'password': password,
        'code': code,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['s'] != true) {
      throw const ApiException('Falha ao redefinir senha');
    }
    final token = (data['jwt'] ?? '').toString();
    if (token.isNotEmpty) {
      await _saveToken(token);
      await _cacheUserData(data, token);
    }
    return UserModel.fromJson(data, token);
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/user/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'password': newPassword,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == false) {
        throw ApiException(data['m']?.toString() ?? 'Senha atual incorreta');
      }
      return true;
    } catch (e) {
      if (e is ApiException) rethrow;
      return true;
    }
  }

  Future<bool> sendSignUpVerificationCode(
    String email, {
    String language = ApiConstants.defaultLanguage,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.sendSignupCode,
      data: {
        'email': email,
        'language': language,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == false) {
      final code = data['c']?.toString();
      String msg = data['m']?.toString() ?? data['message']?.toString() ?? 'Falha ao enviar código';
      if (code == '106') {
        msg = 'Este e-mail já está registrado. Volte e inicie a sessão ou use outro endereço de e-mail.';
      } else if (code == '107') {
        msg = 'Não é possível cadastrar este endereço de e-mail.';
      } else if (code == '125') {
        msg = 'E-mail inválido. Tente com outro endereço de e-mail.';
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }
    return data is Map<String, dynamic> && data['s'] == true;
  }

  Future<bool> verifySignUpCode(String email, String code) async {
    final response = await _apiClient.post(
      ApiConstants.verifyCode,
      data: {
        'email': email,
        'code': code,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == false) {
      final c = data['c']?.toString();
      String msg = 'Código de verificação incorreto';
      if (c == 'invalid_auth_code_msg' || c == '108') {
        msg = 'O código de autenticação não corresponde.';
      } else if (data['m'] != null || data['message'] != null) {
        msg = (data['m'] ?? data['message']).toString();
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }
    return data is Map<String, dynamic> && data['s'] == true;
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String code,
    required String nickname,
    required int categoryId,
    required int countryId,
    String language = ApiConstants.defaultLanguage,
    int version = ApiConstants.defaultVersion,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.createEmailAccount,
      data: {
        'email': email,
        'password': password,
        'code': code,
        'loginProvider': 'Email',
        'language': language,
        'version': version,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic> || data['s'] != true) {
      String msg = 'Erro ao realizar cadastro';
      if (data is Map) {
        final c = data['c']?.toString();
        if (c == '106') {
          msg = 'Este e-mail já está registrado. Volte e inicie a sessão ou use outro endereço de e-mail.';
        } else if (c == '112') {
          msg = 'As senhas não coincidem. Tente novamente.';
        } else if (data['m'] != null || data['message'] != null) {
          msg = (data['m'] ?? data['message']).toString();
        }
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }

    final token = (data['jwt'] ?? '').toString();
    if (token.isEmpty) {
      throw const ApiException('Token JWT não foi retornado pelo servidor');
    }

    await _saveToken(token);

    if (nickname.isNotEmpty) {
      try {
        final nickRes = await _apiClient.post(
          ApiConstants.nicknameChange,
          data: {'nickname': nickname},
        );
        final nickData = nickRes.data;
        if (nickData is Map && nickData['s'] == false) {
          final nc = nickData['c']?.toString();
          if (nc == '104') {
            throw const ApiException('Este apelido já está em uso. Insira outro apelido.');
          } else if (nc == '103' || nc == '116') {
            throw const ApiException('Não é possível usar este apelido. Insira outro apelido.');
          }
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }

    if (categoryId > 0) {
      try {
        await _apiClient.post(
          ApiConstants.categoryByCountry,
          data: {'category_id': categoryId},
        );
      } catch (_) {}
    }

    try {
      final splashData = await splashLogin(language: language);
      if (splashData != null) {
        if (splashData['gs'] != null) data['gs'] = splashData['gs'];
        if (splashData['p'] != null) data['p'] = splashData['p'];
        if (splashData['dl'] != null) data['dl'] = splashData['dl'];
      }
    } catch (_) {}

    await _cacheUserData(data, token);
    return UserModel.fromJson(data, token);
  }

  Future<String?> getStoredToken() async {
    try {
      final token = await _storage
          .read(key: AuthInterceptor.keyJwtToken)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AuthInterceptor.keyJwtToken);
    } catch (_) {}
    return null;
  }

  Future<void> cacheUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyCachedUser, jsonEncode(user.toJson()));
      await prefs.setInt(keyUserEquippedStudiconId, user.studiconId);
    } catch (_) {}
  }

  Future<List<GroupModel>> fetchUserGroups() async {
    try {
      final splashData = await splashLogin();
      if (splashData != null) {
        final groupsRaw = splashData['gs'] ?? splashData['groups'] ?? splashData['userGroups'];
        if (groupsRaw is List) {
          return groupsRaw
              .whereType<Map<String, dynamic>>()
              .map((g) => GroupModel.fromJson(g))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<UserModel?> tryRestoreSession() async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) return null;

    UserModel? user;
    int? savedEquippedStudiconId;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedEquippedStudiconId = prefs.getInt(keyUserEquippedStudiconId);
      final userStr = prefs.getString(keyCachedUser);
      if (userStr != null && userStr.isNotEmpty) {
        final decoded = jsonDecode(userStr);
        if (decoded is Map<String, dynamic>) {
          user = UserModel.fromJson(decoded, token);
          if (savedEquippedStudiconId != null) {
            user = user.copyWith(studiconId: savedEquippedStudiconId);
          }
        }
      }
    } catch (_) {}

    try {
      final splashData = await splashLogin().timeout(const Duration(seconds: 4));
      if (splashData != null) {
        final groupsRaw = splashData['gs'] ?? splashData['groups'] ?? splashData['userGroups'];
        List<GroupModel>? groups;
        if (groupsRaw is List) {
          groups = groupsRaw
              .whereType<Map<String, dynamic>>()
              .map((g) => GroupModel.fromJson(g))
              .toList();
        }

        final p = splashData['p'] is Map ? splashData['p'] as Map<String, dynamic> : null;
        final rawStudiconId = p?['sd'] ?? p?['ssd'] ?? p?['csd'] ?? splashData['sd'] ?? splashData['ssd'] ?? splashData['csd'] ?? splashData['studiconId'];
        final serverSd = rawStudiconId != null ? safeInt(rawStudiconId) : null;
        final resolvedStudiconId = (serverSd != null && serverSd > 0)
            ? serverSd
            : (savedEquippedStudiconId ?? (user?.studiconId ?? -1));

        List<int>? resolvedOwnedIds;
        final rawScs = splashData['scs'];
        if (rawScs is List) {
          resolvedOwnedIds = [];
          for (final item in rawScs) {
            final id = safeInt(item is Map ? (item['id'] ?? item['sc'] ?? item['sd'] ?? item['studiconId']) : item);
            if (id > 0 && !resolvedOwnedIds.contains(id)) resolvedOwnedIds.add(id);
          }
        }

        if (user != null) {
          user = user.copyWith(
            userGroups: groups ?? user.userGroups,
            statusMessage: splashData['stm']?.toString() ?? user.statusMessage,
            studiconId: resolvedStudiconId,
            flamesBalance: (splashData['fl'] as int?) ?? user.flamesBalance,
            ownedStudiconIds: resolvedOwnedIds ?? user.ownedStudiconIds,
          );
        } else {
          user = UserModel.fromJson(splashData, token);
          user = user.copyWith(studiconId: resolvedStudiconId);
        }
        await cacheUser(user);
      }
    } catch (_) {}

    try {
      final response = await _apiClient.post(
        ApiConstants.reloadInfo,
        data: {
          'pv': 2,
          'cd': {},
        },
      ).timeout(const Duration(seconds: 3));
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        if (user != null) {
          final p = data['p'];
          int? serverReloadSd;
          String? updatedStm;
          if (p is Map) {
            final rawSd = p['sd'] ?? p['ssd'] ?? p['csd'];
            if (rawSd != null) {
              final val = safeInt(rawSd);
              if (val > 0) {
                serverReloadSd = val;
              }
            }
            updatedStm = (p['stm'] ?? user.statusMessage).toString();
          }

          List<int>? updatedOwnedIds;
          final reloadScs = data['scs'];
          if (reloadScs is List) {
            updatedOwnedIds = [];
            for (final item in reloadScs) {
              final id = safeInt(item is Map ? (item['id'] ?? item['sc'] ?? item['sd'] ?? item['studiconId']) : item);
              if (id > 0 && !updatedOwnedIds.contains(id)) updatedOwnedIds.add(id);
            }
          }

          final finalStudiconId = serverReloadSd ?? (user.studiconId > 0 ? user.studiconId : (savedEquippedStudiconId ?? user.studiconId));

          user = user.copyWith(
            statusMessage: updatedStm ?? user.statusMessage,
            studiconId: finalStudiconId,
            ownedStudiconIds: updatedOwnedIds ?? user.ownedStudiconIds,
          );
          await cacheUser(user);
        }
      }
    } catch (_) {}

    return user;
  }

  Future<bool> deleteAccount() async {
    final response = await _apiClient.get(ApiConstants.unregister);
    final data = response.data;
    final isSuccess = data is Map<String, dynamic> && data['s'] == true;
    if (isSuccess) {
      await _deleteToken();
    } else if (data is Map && data['c'] == '115') {
      throw const ApiException('Esta conta está protegida contra exclusão devido a um problema em andamento.');
    }
    return isSuccess;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/user/logout', data: {'pushToken': ''});
    } catch (_) {}
    await _deleteToken();
  }
}

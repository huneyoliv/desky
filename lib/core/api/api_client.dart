import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio dio;

  ApiClient({Dio? customDio, FlutterSecureStorage? storage})
      : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    if (customDio == null) {
      dio.interceptors.add(AuthInterceptor(storage ?? const FlutterSecureStorage()));
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) {
    final target = baseUrl != null ? '$baseUrl$path' : path;
    return dio.get(target, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    final target = baseUrl != null ? '$baseUrl$path' : path;
    return dio.post(target, data: data, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    final target = baseUrl != null ? '$baseUrl$path' : path;
    return dio.put(target, data: data, options: options);
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    final target = baseUrl != null ? '$baseUrl$path' : path;
    return dio.delete(target, queryParameters: queryParameters, data: data, options: options);
  }
}

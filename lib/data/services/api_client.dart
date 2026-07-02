import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_storage.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  // Значение вшивается при сборке через --dart-define-from-file.
  // Android эмулятор: http://10.0.2.2:8000/api/v1
  // iOS симулятор:    http://localhost:8000/api/v1
  // Продакшн:         https://piligrim.kz/api/v1
  static const _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://piligrim.kz/api/v1',
  );

  // Подписчики слушают этот стрим, чтобы реагировать на принудительный выход.
  final StreamController<void> onUnauthenticated =
      StreamController.broadcast();

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

    client.interceptors.addAll([
      AuthInterceptor(client, onUnauthenticated, TokenStorage.instance),
      if (kDebugMode) _LoggingInterceptor(),
    ]);

    return client;
  }
}

// ---------------------------------------------------------------------------

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._onUnauthenticated, this._tokenStorage);

  final Dio _dio;
  final StreamController<void> _onUnauthenticated;
  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readAccess();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Пропускаем не-401 и повторные запросы (refresh или retry), чтобы не
    // уйти в рекурсию.
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['_retry'] == true) {
      return handler.next(err);
    }

    final refresh = await _tokenStorage.readRefresh();
    if (refresh == null) {
      await _forceLogout(err, handler);
      return;
    }

    try {
      final response = await _dio.post(
        '/users/auth/token/refresh/',
        data: {'refresh': refresh},
        options: Options(extra: {'_retry': true}),
      );

      final newAccess = response.data['access'] as String?;
      final newRefresh = response.data['refresh'] as String?;

      if (newAccess == null) {
        await _forceLogout(err, handler);
        return;
      }

      await _tokenStorage.saveTokens(
        access: newAccess,
        refresh: newRefresh ?? refresh,
      );

      // Повторяем исходный запрос с новым токеном.
      final retried = await _dio.fetch(
        err.requestOptions
          ..headers['Authorization'] = 'Bearer $newAccess'
          ..extra['_retry'] = true,
      );
      handler.resolve(retried);
    } on DioException {
      await _forceLogout(err, handler);
    }
  }

  Future<void> _forceLogout(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await _tokenStorage.clearTokens();
    _onUnauthenticated.add(null);
    handler.next(err);
  }
}

// ---------------------------------------------------------------------------

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[Dio] --> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[Dio] <-- ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[Dio] ERR ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}',
    );
    handler.next(err);
  }
}

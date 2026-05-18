import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Очередь HTTP-ответов для тестов Dio.
class MockDioAdapter implements HttpClientAdapter {
  final responses = <({int status, Object? body})>[];
  final captured = <RequestOptions>[];

  void enqueue(int status, [Object? body]) =>
      responses.add((status: status, body: body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    if (responses.isEmpty) {
      throw StateError('No mock response for ${options.method} ${options.path}');
    }
    final next = responses.removeAt(0);
    return ResponseBody.fromString(
      next.body == null ? '' : jsonEncode(next.body),
      next.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio createMockDio(MockDioAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

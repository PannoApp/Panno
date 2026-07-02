import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/data/services/api_client.dart';
import 'package:piligrim/data/services/token_storage.dart';

// ---------------------------------------------------------------------------
// Моки
// ---------------------------------------------------------------------------

class _MockTokenStorage extends Mock implements TokenStorage {}

// Адаптер с очередью заранее подготовленных ответов. Также сохраняет все
// входящие RequestOptions для последующих проверок.
class _QueueAdapter implements HttpClientAdapter {
  final _queue = <ResponseBody>[];
  final capturedRequests = <RequestOptions>[];

  void enqueue(ResponseBody response) => _queue.add(response);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    if (_queue.isEmpty) throw StateError('Нет заготовленных ответов');
    return _queue.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

ResponseBody _jsonResponse(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late _MockTokenStorage mockStorage;
  late _QueueAdapter adapter;
  late StreamController<void> unauthCtrl;
  late Dio dio;

  setUp(() {
    mockStorage = _MockTokenStorage();
    adapter = _QueueAdapter();
    unauthCtrl = StreamController.broadcast();

    dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, unauthCtrl, mockStorage));
  });

  tearDown(() => unauthCtrl.close());

  test('AuthInterceptor добавляет заголовок Authorization при наличии токена',
      () async {
    when(() => mockStorage.readAccess()).thenAnswer((_) async => 'my_token');
    adapter.enqueue(_jsonResponse({}, 200));

    await dio.get('/ping');

    expect(
      adapter.capturedRequests.first.headers['Authorization'],
      'Bearer my_token',
    );
  });

  test('AuthInterceptor НЕ добавляет заголовок когда токен null', () async {
    when(() => mockStorage.readAccess()).thenAnswer((_) async => null);
    adapter.enqueue(_jsonResponse({}, 200));

    await dio.get('/ping');

    expect(
      adapter.capturedRequests.first.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('При 401 → вызывается refresh endpoint', () async {
    when(() => mockStorage.readAccess())
        .thenAnswer((_) async => 'expired_token');
    when(() => mockStorage.readRefresh())
        .thenAnswer((_) async => 'refresh_token');
    when(
      () => mockStorage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async {});

    adapter
      ..enqueue(_jsonResponse({}, 401)) // исходный запрос → 401
      ..enqueue(_jsonResponse({'access': 'new_acc', 'refresh': 'new_ref'}, 200))
      ..enqueue(_jsonResponse({'ok': true}, 200)); // retry

    await dio.get('/ping');

    final paths = adapter.capturedRequests.map((r) => r.path).toList();
    expect(paths.any((p) => p.contains('token/refresh')), isTrue);
  });

  test('После успешного refresh → исходный запрос повторяется', () async {
    when(() => mockStorage.readAccess())
        .thenAnswer((_) async => 'expired_token');
    when(() => mockStorage.readRefresh())
        .thenAnswer((_) async => 'refresh_token');
    when(
      () => mockStorage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async {});

    adapter
      ..enqueue(_jsonResponse({}, 401))
      ..enqueue(_jsonResponse({'access': 'new_acc', 'refresh': 'new_ref'}, 200))
      ..enqueue(_jsonResponse({'result': 'retried'}, 200));

    final response = await dio.get('/ping');

    // Все три запроса дошли до адаптера (исходный, refresh, retry).
    expect(adapter.capturedRequests.length, 3);
    expect(response.statusCode, 200);
    expect(response.data['result'], 'retried');
  });

  test('При повторном 401 → clearTokens() вызван', () async {
    when(() => mockStorage.readAccess())
        .thenAnswer((_) async => 'expired_token');
    when(() => mockStorage.readRefresh())
        .thenAnswer((_) async => 'refresh_token');
    when(() => mockStorage.clearTokens()).thenAnswer((_) async {});

    adapter
      ..enqueue(_jsonResponse({}, 401)) // исходный запрос → 401
      ..enqueue(_jsonResponse({}, 401)); // refresh тоже → 401

    try {
      await dio.get('/ping');
    } on DioException {
      // ожидаем ошибку — force logout пробрасывает исходный DioException
    }

    verify(() => mockStorage.clearTokens()).called(1);
  });
}

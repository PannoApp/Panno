import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mock_dio_adapter.dart';

RemoteMessage _message({String? title, String? body, Map<String, dynamic>? data}) {
  return RemoteMessage(
    data: data ?? const {},
    notification: (title != null || body != null)
        ? RemoteNotification(title: title, body: body)
        : null,
  );
}

void main() {
  group('FcmService', () {
    test('registerTokenWithServer posts device register', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      adapter.enqueue(201, {'message': 'ok'});

      final service = FcmService.test(tokenProvider: () async => 'fcm-token-abc');
      await service.registerTokenWithServer(dio);

      expect(adapter.captured, hasLength(1));
      expect(adapter.captured.first.path, contains('/notifications/device/register/'));
      expect(adapter.captured.first.data, {'fcm_token': 'fcm-token-abc'});
    });

    test('registerTokenWithServer skips when token is null', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);

      final service = FcmService.test(tokenProvider: () async => null);
      await service.registerTokenWithServer(dio);

      expect(adapter.captured, isEmpty);
    });

    test('registerTokenWithServer caches token for background isolate', () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      adapter.enqueue(201, {'message': 'ok'});

      final service = FcmService.test(tokenProvider: () async => 'fcm-token-cached');
      await service.registerTokenWithServer(dio);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fcm_token_cache'), 'fcm-token-cached');
    });
  });

  group('logPushReceipt', () {
    test('posts receipt with title/body/data/context', () async {
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      adapter.enqueue(201);

      final message = _message(title: 'Заголовок', body: 'Текст', data: {'type': 'booking'});
      await logPushReceipt(dio, message, context: 'foreground', fcmToken: 'tok-1');

      expect(adapter.captured, hasLength(1));
      final sent = adapter.captured.first;
      expect(sent.path, contains('/notifications/push-receipt/'));
      expect(sent.data, {
        'fcm_token': 'tok-1',
        'title': 'Заголовок',
        'body': 'Текст',
        'data': {'type': 'booking'},
        'context': 'foreground',
      });
    });

    test('skips request when fcmToken is null', () async {
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);

      await logPushReceipt(dio, _message(title: 'T'), context: 'background', fcmToken: null);

      expect(adapter.captured, isEmpty);
    });

    test('skips request when fcmToken is empty', () async {
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);

      await logPushReceipt(dio, _message(title: 'T'), context: 'background', fcmToken: '');

      expect(adapter.captured, isEmpty);
    });

    test('missing notification/data still sends empty strings, not null', () async {
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      adapter.enqueue(201);

      await logPushReceipt(dio, _message(), context: 'opened_app', fcmToken: 'tok-2');

      final sent = adapter.captured.first.data as Map;
      expect(sent['title'], '');
      expect(sent['body'], '');
      expect(sent['data'], <String, String>{});
    });

    test('swallows network/server errors without throwing', () async {
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      adapter.enqueue(500, {'detail': 'server error'});

      await expectLater(
        logPushReceipt(dio, _message(title: 'T'), context: 'foreground', fcmToken: 'tok-3'),
        completes,
      );
    });
  });
}

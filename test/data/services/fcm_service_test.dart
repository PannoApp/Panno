import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/services/fcm_service.dart';

import '../../support/mock_dio_adapter.dart';

void main() {
  group('FcmService', () {
    test('registerTokenWithServer posts device register', () async {
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
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);

      final service = FcmService.test(tokenProvider: () async => null);
      await service.registerTokenWithServer(dio);

      expect(adapter.captured, isEmpty);
    });
  });
}

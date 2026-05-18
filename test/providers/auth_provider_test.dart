import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';

import '../support/fake_token_storage.dart';
import '../support/mock_dio_adapter.dart';

Map<String, dynamic> _sampleProfile() => {
      'id': 42,
      'phone': '+77001234567',
      'first_name': 'Айдар',
      'last_name': 'Нурланов',
      'notify_events': true,
      'notify_promotions': false,
      'notify_closed_events': true,
    };

void main() {
  group('AuthProvider', () {
    late FakeTokenStorage storage;
    late MockDioAdapter adapter;
    AuthProvider buildProvider() {
      final dio = createMockDio(adapter);
      return AuthProvider(
        tokenStorage: storage,
        dio: dio,
        authService: AuthService(dio),
      );
    }

    setUp(() {
      storage = FakeTokenStorage();
      adapter = MockDioAdapter();
    });

    test('init without token → isLoggedIn == false', () async {
      final auth = buildProvider();
      await auth.init();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
      expect(adapter.captured, isEmpty);
    });

    test('init with token → loads profile → isLoggedIn == true', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';
      adapter.enqueue(200, _sampleProfile());

      final auth = buildProvider();
      await auth.init();

      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.id, 42);
      expect(
        adapter.captured.any((r) => r.path.contains('/users/profile/')),
        isTrue,
      );
    });

    test('confirmOtp saves tokens and sets currentUser', () async {
      adapter.enqueue(200, {
        'access': 'access-token',
        'refresh': 'refresh-token',
        'is_new_user': false,
      });
      adapter.enqueue(200, _sampleProfile());

      final auth = buildProvider();
      final ok = await auth.confirmOtp('+77001234567', '1234');

      expect(ok, isTrue);
      expect(storage.access, 'access-token');
      expect(storage.refresh, 'refresh-token');
      expect(auth.currentUser?.phone, '+77001234567');
    });

    test('logout clears tokens and currentUser', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';
      adapter.enqueue(200, _sampleProfile());
      adapter.enqueue(200, <String, dynamic>{});

      final auth = buildProvider();
      await auth.init();
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
    });

    test('updateNotificationPreferences patches profile', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';
      adapter.enqueue(200, _sampleProfile());
      adapter.enqueue(200, {
        ..._sampleProfile(),
        'notify_promotions': true,
      });

      final auth = buildProvider();
      await auth.init();
      await auth.updateNotificationPreferences(promotions: true);

      expect(auth.currentUser?.notifyPromotions, isTrue);
    });
  });
}

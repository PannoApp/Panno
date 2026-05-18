import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';

import '../support/fake_api_client.dart';
import '../support/fake_token_storage.dart';

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
    late FakeApiClient api;

    setUp(() {
      storage = FakeTokenStorage();
      api = FakeApiClient(
        tokenStorage: storage,
        getResponses: {'/users/profile/': _sampleProfile()},
        postResponses: {
          '/auth/verify-sms/': {
            'access': 'access-token',
            'refresh': 'refresh-token',
            'is_new_user': false,
          },
          '/auth/logout/': <String, dynamic>{},
        },
        patchResponses: {
          '/users/profile/': {
            ..._sampleProfile(),
            'notify_promotions': true,
          },
        },
      );
    });

    AuthProvider buildProvider() {
      return AuthProvider(
        tokenStorage: storage,
        apiClient: api,
        authService: AuthService(api),
      );
    }

    test('init without token → isLoggedIn == false', () async {
      final auth = buildProvider();
      await auth.init();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
      expect(api.getCalls, isEmpty);
    });

    test('init with token → loads profile → isLoggedIn == true', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';

      final auth = buildProvider();
      await auth.init();

      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.id, 42);
      expect(auth.currentUser?.firstName, 'Айдар');
      expect(api.getCalls, contains('/users/profile/'));
    });

    test('confirmOtp saves tokens and sets currentUser', () async {
      final auth = buildProvider();
      final ok = await auth.confirmOtp('+77001234567', '1234');

      expect(ok, isTrue);
      expect(storage.access, 'access-token');
      expect(storage.refresh, 'refresh-token');
      expect(auth.currentUser?.phone, '+77001234567');
      expect(api.postCalls, contains('/auth/verify-sms/'));
    });

    test('logout clears tokens and currentUser', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';
      final auth = buildProvider();
      await auth.init();
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
      expect(api.postCalls, contains('/auth/logout/'));
    });

    test('updateNotificationPreferences patches profile', () async {
      storage.access = 'stored-access';
      storage.refresh = 'stored-refresh';
      final auth = buildProvider();
      await auth.init();

      await auth.updateNotificationPreferences(promotions: true);

      expect(auth.currentUser?.notifyPromotions, isTrue);
      expect(api.patchCalls, contains('/users/profile/'));
    });
  });
}

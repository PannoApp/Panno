import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/user_profile.dart';
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
      'notifications_enabled': true,
      'date_joined': '2024-03-15T10:00:00Z',
    };

void _enqueueEmptyReservations(MockDioAdapter adapter) {
  adapter.enqueue(200, {'count': 0, 'results': []});
}

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
      _enqueueEmptyReservations(adapter);

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
      _enqueueEmptyReservations(adapter);

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
      _enqueueEmptyReservations(adapter);
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
      _enqueueEmptyReservations(adapter);
      adapter.enqueue(200, {
        ..._sampleProfile(),
        'notify_promotions': true,
      });

      final auth = buildProvider();
      await auth.init();
      await auth.updateNotificationPreferences(promotions: true);

      expect(auth.currentUser?.notifyPromotions, isTrue);
    });

    test('confirmOtp sets isNewUser from verify response', () async {
      adapter.enqueue(200, {
        'access': 'access-token',
        'refresh': 'refresh-token',
        'is_new_user': true,
      });
      adapter.enqueue(200, _sampleProfile());
      _enqueueEmptyReservations(adapter);

      final auth = buildProvider();
      await auth.confirmOtp('+77001234567', '1234');

      expect(auth.isNewUser, isTrue);
    });

    test('user journeyStartLabel from date_joined', () async {
      storage.access = 'stored-access';
      adapter.enqueue(200, _sampleProfile());
      _enqueueEmptyReservations(adapter);

      final auth = buildProvider();
      await auth.init();

      expect(auth.user.journeyStartLabel, 'Март 2024');
    });

    test('updateNotificationPreferences sends notifications_enabled', () async {
      storage.access = 'stored-access';
      adapter.enqueue(200, _sampleProfile());
      _enqueueEmptyReservations(adapter);
      adapter.enqueue(200, {
        ..._sampleProfile(),
        'notifications_enabled': false,
      });

      final auth = buildProvider();
      await auth.init();
      await auth.updateNotificationPreferences(notificationsEnabled: false);

      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {'notifications_enabled': false});
      expect(auth.currentUser?.notificationsEnabled, isFalse);
    });

    test('updateDisplayProfile sends gender/email/birthday in PATCH body', () async {
      storage.access = 'stored-access';
      adapter.enqueue(200, _sampleProfile());
      _enqueueEmptyReservations(adapter);
      adapter.enqueue(200, {
        ..._sampleProfile(),
        'gender': 'male',
        'email': 'a@example.com',
        'birthday': '1995-05-20',
      });

      final auth = buildProvider();
      await auth.init();
      await auth.updateDisplayProfile(
        gender: UserGender.male,
        email: 'a@example.com',
        birthday: DateTime(1995, 5, 20),
      );

      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {
        'gender': 'male',
        'email': 'a@example.com',
        'birthday': '1995-05-20',
      });
      expect(auth.currentUser?.gender, UserGender.male);
      expect(auth.currentUser?.email, 'a@example.com');
    });

    test('updateDisplayProfile omits unset optional fields', () async {
      storage.access = 'stored-access';
      adapter.enqueue(200, _sampleProfile());
      _enqueueEmptyReservations(adapter);
      adapter.enqueue(200, {..._sampleProfile(), 'first_name': 'Данияр'});

      final auth = buildProvider();
      await auth.init();
      await auth.updateDisplayProfile(firstName: 'Данияр');

      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {'first_name': 'Данияр'});
    });

    test('init loads eventsCount from reservations API', () async {
      storage.access = 'stored-access';
      adapter.enqueue(200, _sampleProfile());
      adapter.enqueue(200, {
        'count': 2,
        'results': [{'id': 1}, {'id': 2}],
      });

      final auth = buildProvider();
      await auth.init();

      expect(auth.eventsCount, 2);
      expect(auth.user.eventsCount, 2);
    });
  });
}

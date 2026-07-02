// ProfileScreen: бесконечные анимации в шапке — pump(), не pumpAndSettle().
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:piligrim/data/models/api_booking.dart';
import 'package:piligrim/data/models/core_info.dart';
import 'package:piligrim/data/models/user_profile.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/providers/booking_provider.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:piligrim/screens/booking_history_screen.dart';
import 'package:piligrim/screens/profile_screen.dart';

import '../support/fake_token_storage.dart';
import '../support/mock_dio_adapter.dart';

UserProfile _sampleProfile() => const UserProfile(
      id: 1,
      phone: '+77001234567',
      firstName: 'Айдар',
      lastName: 'Нурланов',
      notifyEvents: true,
      notifyPromotions: false,
      notifyClosedEvents: false,
      notificationsEnabled: true,
    );

CoreInfo _coreInfo({String privacyPolicy = 'https://api.piligrim.kz/privacy'}) =>
    CoreInfo(
      address: 'Астана',
      workingHours: '12:00–23:00',
      isOpenNow: true,
      phone: '+77001234567',
      socialLinks: const [],
      heroSlides: const [],
      bookingDepositRequired: false,
      visitRules: const [],
      privacyPolicy: privacyPolicy,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileScreen', () {
    late MockDioAdapter adapter;
    late AuthProvider auth;
    late BookingProvider booking;
    late CoreInfoProvider core;
    String? launchedUrl;

    setUp(() {
      adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      auth = AuthProvider(
        tokenStorage: FakeTokenStorage(),
        dio: dio,
        authService: AuthService(dio),
      );
      booking = BookingProvider();
      core = CoreInfoProvider();
      launchedUrl = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          final args = call.arguments as Map?;
          if (call.method == 'canLaunch') return true;
          if (call.method == 'launch') {
            launchedUrl = args?['url'] as String?;
            return true;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      );
    });

    Widget buildApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<BookingProvider>.value(value: booking),
          ChangeNotifierProvider<CoreInfoProvider>.value(value: core),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('При isLoggedIn=false → форма авторизации видна',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Сначала нужно авторизоваться'), findsOneWidget);
      expect(find.text('ПОЛУЧИТЬ КОД'), findsOneWidget);
    });

    testWidgets('При isLoggedIn=true → имя и телефон из currentUser',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Айдар Нурланов'), findsOneWidget);
      expect(find.text('+77001234567'), findsOneWidget);
      expect(find.text('Сначала нужно авторизоваться'), findsNothing);
    });

    testWidgets('Переключение «Мероприятия» → PATCH notify_events',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      adapter.enqueue(200, {
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'Айдар',
        'last_name': 'Нурланов',
        'notify_events': false,
        'notify_promotions': false,
        'notify_closed_events': false,
      });

      await tester.pumpWidget(buildApp());
      await settle(tester);

      final eventsLabel = find.text('Мероприятия');
      await scrollTo(tester, eventsLabel);
      final toggle = find.descendant(
        of: find.ancestor(
          of: eventsLabel,
          matching: find.byType(Row),
        ),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(toggle);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {'notify_events': false});
      expect(auth.currentUser?.notifyEvents, isFalse);
    });

    testWidgets('Тап «Бронирований» → BookingHistoryScreen', (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      booking.history = const [
        ApiBooking(
          id: 1,
          guestName: 'Айдар',
          phone: '+77001234567',
          date: '2026-05-20',
          time: '19:00',
          guestsCount: 2,
          status: 'confirmed',
        ),
      ];

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('1'), findsWidgets);

      await tester.ensureVisible(find.text('Бронирований'));
      await tester.tap(find.text('Бронирований'));
      await settle(tester);

      expect(find.byType(BookingHistoryScreen), findsOneWidget);
    });

    testWidgets('Privacy link использует URL из CoreInfoProvider',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      core.coreInfo = _coreInfo(
        privacyPolicy: 'https://api.piligrim.kz/legal/privacy',
      );

      await tester.pumpWidget(buildApp());
      await settle(tester);

      final privacy = find.text('Политика конфиденциальности');
      await scrollTo(tester, privacy);
      await tester.tap(privacy);
      await settle(tester);

      expect(launchedUrl, 'https://api.piligrim.kz/legal/privacy');
    });

    testWidgets('Ввод телефона и получение кода в _UnauthProfileView', (tester) async {
      adapter.enqueue(200, {});

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Сначала нужно авторизоваться'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '+77001234567');
      await tester.pump();

      await tester.tap(find.text('ПОЛУЧИТЬ КОД'));
      await settle(tester);

      expect(find.text('Код отправлен на +77001234567'), findsOneWidget);
      expect(find.text('ПОДТВЕРДИТЬ'), findsOneWidget);
    });

    testWidgets('При notificationsEnabled: false категории визуально задизаблены',
        (tester) async {
      auth.currentUser = const UserProfile(
        id: 1,
        phone: '+77001234567',
        firstName: 'Айдар',
        lastName: 'Нурланов',
        notifyEvents: true,
        notifyPromotions: false,
        notifyClosedEvents: false,
        notificationsEnabled: false,
      );
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      await scrollTo(tester, find.text('Мероприятия'));
      // Ждём завершения flutter_animate анимаций (delay 150ms + duration 600ms)
      await tester.pump(const Duration(milliseconds: 800));

      // Блок категорий завёрнут в Opacity с opacity 0.4
      final dimmed = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) => o.opacity == 0.4)
          .toList();
      expect(dimmed, isNotEmpty);
    });

    testWidgets('Глобальный переключатель → PATCH notifications_enabled',
        (tester) async {
      auth.currentUser = _sampleProfile(); // notificationsEnabled: true
      auth.notifyListeners();
      adapter.enqueue(200, {
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'Айдар',
        'last_name': 'Нурланов',
        'notify_events': true,
        'notify_promotions': false,
        'notify_closed_events': false,
        'notifications_enabled': false,
      });

      await tester.pumpWidget(buildApp());
      await settle(tester);

      final globalLabel = find.text('Уведомления');
      await scrollTo(tester, globalLabel);
      final toggle = find.descendant(
        of: find.ancestor(
          of: globalLabel,
          matching: find.byType(Row),
        ),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(toggle.first);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {'notifications_enabled': false});
      expect(auth.currentUser?.notificationsEnabled, isFalse);
    });
  });
}

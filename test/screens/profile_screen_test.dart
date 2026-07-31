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
        // В реальном приложении ProfileScreen всегда живёт внутри общего
        // Scaffold RootShell (см. lib/main.dart) — сама она Scaffold не
        // создаёт в неавторизованном состоянии (PiligrimAuthView без Material
        // ancestor). Оборачиваем так же, иначе TextField падает с
        // "No Material widget found".
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
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

      // PiligrimAuthView: мини-заголовок формы и CTA (см.
      // lib/widgets/piligrim_auth_view.dart, ветка !_awaitingCode).
      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.text('ПОЛУЧИТЬ КОД'), findsOneWidget);
    });

    testWidgets('При isLoggedIn=true → имя героя из currentUser',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      // _HeroHeader показывает только имя (первое слово из displayName),
      // телефон в шапке не отображается — см. lib/screens/profile_screen.dart.
      expect(find.text('Айдар'), findsOneWidget);
      expect(find.text('ПОЛУЧИТЬ КОД'), findsNothing);
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

    testWidgets('Кэшбек из профиля отображается отформатированной суммой',
        (tester) async {
      auth.currentUser = const UserProfile(
        id: 1,
        phone: '+77001234567',
        firstName: 'Айдар',
        lastName: 'Нурланов',
        notifyEvents: true,
        notifyPromotions: false,
        notifyClosedEvents: false,
        notificationsEnabled: true,
        cashback: 12500,
      );
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Кэшбек'), findsOneWidget);
      expect(find.text('12 500 ₸'), findsOneWidget);
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

      // _pluralize(1, ...) → форма единственного числа «Бронирование».
      await tester.ensureVisible(find.text('Бронирование'));
      await tester.tap(find.text('Бронирование'));
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

      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '+77001234567');
      await tester.pump();

      await tester.tap(find.text('ПОЛУЧИТЬ КОД'));
      await settle(tester);
      // AnimatedSwitcher (280ms) + цепочка .animate().fadeIn(delay: до 420ms)
      // на новых полях формы — даём им доиграть, иначе таймер остаётся
      // висеть после разрушения дерева виджетов в конце теста.
      await tester.pump(const Duration(milliseconds: 500));

      // PiligrimAuthView (_awaitingCode=true): заголовок «ВВЕДИТЕ КОД» +
      // введённый номер под ним, отдельными Text-виджетами (без префикса
      // «Код отправлен на»).
      expect(find.text('ВВЕДИТЕ КОД'), findsOneWidget);
      expect(find.text('+77001234567'), findsOneWidget);
      expect(find.text('ПОДТВЕРДИТЬ'), findsOneWidget);
    });

    testWidgets('Глобальный переключатель → PATCH всех категорий разом',
        (tester) async {
      // Глобальный тумблер «Уведомления» отражает globalEnabled =
      // notifyEvents && notifyPromotions && notifyClosedEvents (все три сразу),
      // а не отдельное notifications_enabled — поэтому для теста «выключения»
      // фикстура должна начинаться со всех трёх флагов включёнными.
      auth.currentUser = const UserProfile(
        id: 1,
        phone: '+77001234567',
        firstName: 'Айдар',
        lastName: 'Нурланов',
        notifyEvents: true,
        notifyPromotions: true,
        notifyClosedEvents: true,
        notificationsEnabled: true,
      );
      auth.notifyListeners();
      adapter.enqueue(200, {
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'Айдар',
        'last_name': 'Нурланов',
        'notify_events': false,
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

      // _handleNotifToggle('global', ...) шлёт все четыре поля одним PATCH —
      // см. lib/screens/profile_screen.dart, case 'global'.
      final patch = adapter.captured
          .where((r) => r.method == 'PATCH' && r.path == '/users/profile/')
          .single;
      expect(patch.data, {
        'notifications_enabled': false,
        'notify_events': false,
        'notify_promotions': false,
        'notify_closed_events': false,
      });
      expect(auth.currentUser?.notificationsEnabled, isFalse);
    });
  });
}

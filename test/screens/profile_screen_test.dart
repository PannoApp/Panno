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

    testWidgets(
        '_LoyaltyCard отображает баланс, % кешбэка и имя гостя из профиля',
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
        loyaltyPercent: '3%',
      );
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('БАЛАНС'), findsOneWidget);
      expect(find.text('12 500 ₸'), findsOneWidget);
      expect(find.text('ГОСТЬ'), findsOneWidget);
      expect(find.text('Айдар Нурланов'), findsOneWidget);
      expect(find.text('КЕШБЭК'), findsOneWidget);
      expect(find.text('3%'), findsOneWidget);

      // loyaltyCardUrl не задан → карта QR ещё не пришла из Remarked, показан placeholder.
      expect(find.text('Карта появится после первого визита'), findsOneWidget);
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
      // «Код отправлен на»). KzPhoneInputFormatter форматирует ввод с
      // пробелами: '+7 700 123 45 67' — тот же номер, что и '+77001234567'.
      expect(find.text('ВВЕДИТЕ КОД'), findsOneWidget);
      expect(find.text('+7 700 123 45 67'), findsOneWidget);
      expect(find.text('ПОДТВЕРДИТЬ'), findsOneWidget);
    });
  });
}

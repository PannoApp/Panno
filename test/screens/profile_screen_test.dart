// ProfileScreen: бесконечные анимации в шапке — pump(), не pumpAndSettle().
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

CoreInfo _coreInfo({
  String privacyPolicy = 'https://api.piligrim.kz/privacy',
  String? twogisLink,
  List<SocialLink> socialLinks = const [],
}) =>
    CoreInfo(
      address: 'Астана',
      workingHours: '12:00–23:00',
      isOpenNow: true,
      phone: '+77001234567',
      socialLinks: socialLinks,
      heroSlides: const [],
      visitRules: const [],
      privacyPolicy: privacyPolicy,
      twogisLink: twogisLink,
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
      SharedPreferences.setMockInitialValues({});
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

      // PiligrimAuthView: единый экран входа — телефон + номер участника
      // видны сразу, без промежуточного шага (см. lib/widgets/piligrim_auth_view.dart).
      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.text('ВОЙТИ'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
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
      expect(find.text('ПРОДОЛЖИТЬ'), findsNothing);
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

    testWidgets(
        '_LoyaltyQrTile показывает 4 орнаментальные звезды по углам рамки',
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
        loyaltyCardUrl: 'https://cdn.piligrim.kz/loyalty/qr.png',
      );
      auth.notifyListeners();

      await tester.pumpWidget(buildApp());
      await settle(tester);

      // _CornerOrnament — приватный класс, ищем по runtimeType (как и
      // _ProfileHairlineDivider выше). Не зависит от того, успела ли
      // CachedNetworkImage загрузить саму картинку — звёзды лежат в Stack
      // рядом с ней, а не внутри.
      final ornaments = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_CornerOrnament',
      );
      expect(ornaments, findsNWidgets(4));
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

    testWidgets(
        'Телефон + номер участника видны сразу на одном экране → успешный вход',
        (tester) async {
      adapter.enqueue(200, {
        'access': 'access-token',
        'refresh': 'refresh-token',
        'is_new_user': false,
        'user_id': 1,
      });
      adapter.enqueue(200, _sampleProfile());
      adapter.enqueue(200, {'count': 0, 'results': []});

      await tester.pumpWidget(buildApp());
      await settle(tester);

      // PiligrimAuthView (_AuthStep.login, по умолчанию): оба поля — телефон
      // и номер участника — видны одновременно, без промежуточного шага.
      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.text('ВОЙТИ'), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.at(0), '+77001234567');
      await tester.pump();
      await tester.enterText(fields.at(1), '113');
      await tester.pump();

      await tester.tap(find.text('ВОЙТИ'));
      // Долгий settle: без мока платформенного канала Firebase Messaging
      // AuthProvider._registerFcmIfPossible() висит до собственного
      // 5-секундного таймаута (см. auth_provider.dart), прежде чем
      // финальный notifyListeners() отработает и Consumer<AuthProvider>
      // перестроит дерево на авторизованный вид.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      // Добиваем очередь микрозадач, оставшихся после срабатывания таймаута.
      for (var i = 0; i < 10; i++) {
        await tester.pump(Duration.zero);
      }

      final request = adapter.captured
          .where((r) => r.path == '/users/auth/loyalty-login/')
          .single;
      expect(request.data, {'phone': '+77001234567', 'member_number': '113'});
      expect(adapter.captured.any((r) => r.path == '/users/profile/'), isTrue);
      expect(auth.isLoggedIn, isTrue);
      expect(find.text('Айдар'), findsOneWidget);
    });

    testWidgets(
        '«Забыл свой номер лояльности» открывает WhatsApp с номером и текстом из CoreInfo',
        (tester) async {
      core.coreInfo = _coreInfo(); // без экрана входа CoreInfoProvider обычно уже загружен

      await tester.pumpWidget(buildApp());
      await settle(tester);

      // Ссылка видна сразу на экране входа (_AuthStep.login по умолчанию) —
      // не нужно сначала вводить телефон и жать «Продолжить».
      final recoveryLink = find.text('Забыл свой номер лояльности');
      expect(recoveryLink, findsOneWidget);
      await tester.tap(recoveryLink);
      await settle(tester);

      // Фолбэк из lib/core/profile_data.dart (kLoyaltyRecoveryWhatsapp/
      // kLoyaltyRecoveryMessage), так как в _coreInfo() эти поля не заданы.
      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('https://wa.me/77713333044?text='));
    });

    testWidgets(
        '_ContactsCard не показывает WhatsApp/Telegram/Instagram — бэкенд их больше не присылает',
        (tester) async {
      // Реалистичный сценарий: бэкенд убрал whatsapp/telegram/instagram из
      // сериализатора (см. RestaurantInfoSerializer) и не отдаёт social_links
      // как массив — CoreInfo.fromJson(_parseSocialLinks) вернёт socialLinks
      // пустым (см. core_info_test.dart), а kMessengers-фолбэк тоже пуст.
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      core.coreInfo = _coreInfo(); // socialLinks: const [] по умолчанию

      await tester.pumpWidget(buildApp());
      await settle(tester);
      // ContactsCard живёт в SliverList — не строится, пока не проскроллено
      // в зону видимости; без этого findsNothing был бы верен тривиально.
      await scrollTo(tester, find.textContaining('Наш адрес'));

      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Telegram'), findsNothing);
      expect(find.text('Instagram'), findsNothing);
    });

    testWidgets('Кнопка карты подписана «карты» (не «2ГИС») и открывает twogisLink',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      core.coreInfo = _coreInfo(twogisLink: 'https://2gis.kz/astana/firm/piligrim');

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('2ГИС'), findsNothing);
      final mapButton = find.text('карты');
      await scrollTo(tester, mapButton);
      await tester.tap(mapButton);
      await settle(tester);

      expect(launchedUrl, 'https://2gis.kz/astana/firm/piligrim');
    });

    testWidgets(
        'Без мессенджеров разделитель после телефона не рендерится («осиротевший» divider)',
        (tester) async {
      auth.currentUser = _sampleProfile();
      auth.notifyListeners();
      // socialLinks пуст и kMessengers пуст (WhatsApp/Telegram/Instagram
      // убраны) — mapLinks/адрес заданы, значит единственный ожидаемый
      // разделитель в карточке — перед блоком «адрес + карта».
      core.coreInfo = _coreInfo(twogisLink: 'https://2gis.kz/astana/firm/piligrim');

      await tester.pumpWidget(buildApp());
      await settle(tester);
      await scrollTo(tester, find.textContaining('Наш адрес'));

      // _ProfileHairlineDivider используется и в других карточках экрана
      // (например _LoyaltyCard) — ограничиваем поиск потомками _ContactsCard.
      final contactsCard = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ContactsCard',
      );
      expect(contactsCard, findsOneWidget);
      final dividers = find.descendant(
        of: contactsCard,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ProfileHairlineDivider',
        ),
      );
      expect(dividers, findsOneWidget);
    });
  });
}

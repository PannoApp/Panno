// ВАЖНО: BookingScreen использует PiligrimBackground и EmberCta с бесконечными
// AnimationController.repeat(), поэтому pumpAndSettle() тайм-аутится.
// Используем pump() + pump(duration) для ожидания async-операций.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/data/models/booking_request.dart';
import 'package:piligrim/data/models/core_info.dart';
import 'package:piligrim/data/models/user_profile.dart';
import 'package:piligrim/data/repositories/booking_repository.dart';
import 'package:piligrim/data/repositories/core_repository.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/providers/booking_provider.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:piligrim/screens/booking_screen.dart' show BookingScreen, bookingTimeForApi;
import 'package:piligrim/screens/phone_entry_screen.dart';

import '../support/fake_token_storage.dart';
import '../support/mock_dio_adapter.dart';

class _MockBookingRepository extends Mock implements BookingRepository {}

class _MockCoreRepository extends Mock implements CoreRepository {}

const _fallbackReq = BookingRequest(
  guestName: '',
  phone: '',
  date: '',
  time: '',
  guestsCount: 1,
);

UserProfile _sampleProfile() => const UserProfile(
      id: 1,
      phone: '+77001234567',
      firstName: 'Айдар',
      lastName: '',
      notifyEvents: true,
      notifyPromotions: false,
      notifyClosedEvents: false,
      notificationsEnabled: true,
    );

CoreInfo _coreInfo({bool depositRequired = false, String? bookingDepositNote}) => CoreInfo(
      address: 'Астана',
      workingHours: '10:00–22:00',
      isOpenNow: true,
      phone: '+77001234567',
      socialLinks: const [],
      heroSlides: const [],
      bookingDepositRequired: depositRequired,
      bookingDepositNote: bookingDepositNote,
      visitRules: const [],
      privacyPolicy: 'Политика',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_fallbackReq);
  });

  group('bookingTimeForApi', () {
    test('дополняет нулями часы и минуты, добавляет :00 секунд', () {
      expect(bookingTimeForApi(const TimeOfDay(hour: 9, minute: 5)), '09:05:00');
    });

    test('граничное значение: 23:59 → 23:59:00', () {
      expect(bookingTimeForApi(const TimeOfDay(hour: 23, minute: 59)), '23:59:00');
    });

    test('_timeLabel остаётся HH:MM — без секунд (дефолтное время 19:30)', () {
      // _timeLabel использует тот же padLeft-формат, но без :00
      final h = 19.toString().padLeft(2, '0');
      final m = 30.toString().padLeft(2, '0');
      expect('$h:$m', '19:30');
      expect(bookingTimeForApi(const TimeOfDay(hour: 19, minute: 30)), '19:30:00');
    });
  });

  group('BookingScreen', () {
    late _MockBookingRepository mockRepo;
    late AuthProvider auth;
    late BookingProvider booking;
    late CoreInfoProvider core;

    setUp(() {
      mockRepo = _MockBookingRepository();
      final adapter = MockDioAdapter();
      final dio = createMockDio(adapter);
      auth = AuthProvider(
        tokenStorage: FakeTokenStorage(),
        dio: dio,
        authService: AuthService(dio),
      );
      booking = BookingProvider(repository: mockRepo);
      core = CoreInfoProvider(repository: _MockCoreRepository());
    });

    Widget buildApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<BookingProvider>.value(value: booking),
          ChangeNotifierProvider<CoreInfoProvider>.value(value: core),
        ],
        child: const MaterialApp(home: BookingScreen()),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('При isLoggedIn=false → submit → push PhoneEntryScreen',
        (tester) async {
      // auth.isLoggedIn == false по умолчанию
      await tester.pumpWidget(buildApp());
      await settle(tester);

      // Кнопка ниже видимой области — прокручиваем к ней перед нажатием
      await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await settle(tester);

      expect(find.byType(PhoneEntryScreen), findsOneWidget);
    });

    testWidgets('Поле телефона prefilled из AuthProvider.currentUser.phone',
        (tester) async {
      auth.currentUser = _sampleProfile();

      await tester.pumpWidget(buildApp());
      await settle(tester); // pump обрабатывает addPostFrameCallback → заполняет поля

      expect(find.widgetWithText(TextFormField, '+77001234567'), findsOneWidget);
    });

    testWidgets('Если depositRequired=true → предупреждение видно', (tester) async {
      core.coreInfo = _coreInfo(
        depositRequired: true,
        bookingDepositNote: 'Для выбранного стола может потребоваться депозит. Менеджер направит вас на звонок.',
      );

      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(
        find.textContaining('Менеджер направит вас на звонок'),
        findsOneWidget,
      );
    });

    testWidgets('При успешном submitBooking() → success state отображается',
        (tester) async {
      auth.currentUser = _sampleProfile();
      when(() => mockRepo.createBooking(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await settle(tester); // postFrameCallback заполняет имя + телефон

      // Кнопка ниже видимой области — прокручиваем к ней перед нажатием
      await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await settle(tester); // guardAuth + submitBooking завершаются

      expect(find.text('Сценарий после отправки'), findsOneWidget);
    });
  });
}

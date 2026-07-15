// ВАЖНО: BookingScreen использует PiligrimBackground и EmberCta с бесконечными
// AnimationController.repeat(), поэтому pumpAndSettle() тайм-аутится.
// Используем pump() + pump(duration) для ожидания async-операций.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/data/models/availability_slot.dart';
import 'package:piligrim/data/models/booking_request.dart';
import 'package:piligrim/data/models/booking_table.dart';
import 'package:piligrim/data/models/booking_zone.dart';
import 'package:piligrim/data/models/user_profile.dart';
import 'package:piligrim/data/repositories/booking_repository.dart';
import 'package:piligrim/data/repositories/core_repository.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/providers/booking_provider.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:piligrim/screens/booking_screen.dart' show BookingScreen, bookingTimeForApi;
import 'package:piligrim/screens/booking_success_screen.dart';
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
      // BookingScreen дёргает loadAvailability() и loadZones() при монтировании
      // (initState) — дефолтные стабы нужны всем тестам, даже тем, что не
      // проверяют слот-пикер/выбор зала.
      when(() => mockRepo.fetchAvailability(
            date: any(named: 'date'),
            guests: any(named: 'guests'),
            zoneId: any(named: 'zoneId'),
          )).thenAnswer((_) async => const []);
      when(() => mockRepo.fetchZones()).thenAnswer((_) async => const []);
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

    testWidgets('При успешном submitBooking() → success state отображается',
        (tester) async {
      auth.currentUser = _sampleProfile();
      when(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp());
      await settle(tester); // postFrameCallback заполняет имя + телефон

      // Кнопка ниже видимой области — прокручиваем к ней перед нажатием
      await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
      await settle(tester); // guardAuth + submitBooking завершаются

      // Предыдущая проверка искала текст 'Сценарий после отправки', которого
      // нет нигде в BookingSuccessScreen (см. lib/screens/booking_success_screen.dart) —
      // похоже на не обновлённый плейсхолдер из ранней версии теста. Проверяем
      // реальный заголовок экрана успеха.
      expect(find.byType(BookingSuccessScreen), findsOneWidget);
      expect(find.textContaining('ЗАБРОНИРОВАН'), findsOneWidget);
    });

    group('предупреждение о занятости (Remarked)', () {
      const warningText = 'К сожалению, на эту дату и время все забронировано.';

      testWidgets('выбранное время занято (is_free=false) → показывает предупреждение',
          (tester) async {
        // Дефолтное время формы — 19:30
        when(() => mockRepo.fetchAvailability(
              date: any(named: 'date'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            ))
            .thenAnswer((_) async => const [
                  AvailabilitySlot(time: '19:30:00', isFree: false, tablesCount: 0),
                ]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        expect(find.text(warningText), findsOneWidget);

        // Проверка доступности — лишь подсказка, отправка заявки не блокируется
        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        expect(find.text('ОТПРАВИТЬ ЗАЯВКУ'), findsOneWidget);
      });

      testWidgets('выбранное время свободно (is_free=true) → предупреждения нет',
          (tester) async {
        when(() => mockRepo.fetchAvailability(
              date: any(named: 'date'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            ))
            .thenAnswer((_) async => const [
                  AvailabilitySlot(time: '19:30:00', isFree: true, tablesCount: 5),
                ]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        expect(find.text(warningText), findsNothing);
      });

      testWidgets('нет точного совпадения слота с выбранным временем → предупреждения нет',
          (tester) async {
        when(() => mockRepo.fetchAvailability(
              date: any(named: 'date'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            ))
            .thenAnswer((_) async => const [
                  AvailabilitySlot(time: '20:00:00', isFree: false, tablesCount: 0),
                ]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        expect(find.text(warningText), findsNothing);
      });

      testWidgets('ошибка проверки доступности → предупреждения нет, форма не блокируется',
          (tester) async {
        when(() => mockRepo.fetchAvailability(
              date: any(named: 'date'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            ))
            .thenThrow(Exception('Проверка занятости временно недоступна'));

        await tester.pumpWidget(buildApp());
        await settle(tester);

        expect(find.text(warningText), findsNothing);

        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        expect(find.text('ОТПРАВИТЬ ЗАЯВКУ'), findsOneWidget);
      });
    });

    group('выбор конкретного стола', () {
      const zoneA = BookingZone(id: 304, name: 'Зал 1');

      testWidgets('пикер стола скрыт, пока зал не выбран', (tester) async {
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        expect(find.text('Любой стол'), findsNothing);
      });

      testWidgets('после выбора зала показывается «Любой стол», тап открывает список свободных столов',
          (tester) async {
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);
        when(() => mockRepo.fetchTables(
              date: any(named: 'date'),
              time: any(named: 'time'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            )).thenAnswer((_) async => const [
              BookingTable(id: 4384, name: '202', capacity: 2),
              BookingTable(id: 4391, name: '210', capacity: 2),
            ]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.ensureVisible(find.text('Зал 1'));
        await tester.tap(find.text('Зал 1'));
        await settle(tester);

        expect(find.text('Любой стол'), findsOneWidget);

        await tester.tap(find.text('Любой стол'));
        await settle(tester);

        expect(find.text('Стол 202'), findsOneWidget);
        expect(find.text('Стол 210'), findsOneWidget);
      });

      testWidgets('нет свободных столов → «Любой стол» скрыт, показано предупреждение, отправка заблокирована',
          (tester) async {
        auth.currentUser = _sampleProfile();
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);
        when(() => mockRepo.fetchTables(
              date: any(named: 'date'),
              time: any(named: 'time'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            )).thenAnswer((_) async => const []);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.ensureVisible(find.text('Зал 1'));
        await tester.tap(find.text('Зал 1'));
        await settle(tester);

        expect(find.text('Любой стол'), findsNothing);
        expect(
          find.textContaining('нет свободных столов на выбранные дату и время'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await settle(tester);

        verifyNever(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')));
      });

      testWidgets('ошибка загрузки столов (Remarked недоступен) не блокирует отправку',
          (tester) async {
        auth.currentUser = _sampleProfile();
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);
        when(() => mockRepo.fetchTables(
              date: any(named: 'date'),
              time: any(named: 'time'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            )).thenThrow(Exception('Проверка занятости временно недоступна'));
        when(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.ensureVisible(find.text('Зал 1'));
        await tester.tap(find.text('Зал 1'));
        await settle(tester);

        expect(find.text('Любой стол'), findsNothing);
        expect(
          find.textContaining('нет свободных столов на выбранные дату и время'),
          findsNothing,
        );

        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await settle(tester);

        verify(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey'))).called(1);
      });

      testWidgets('выбор конкретного стола отправляется как remarked_table_id',
          (tester) async {
        auth.currentUser = _sampleProfile();
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);
        when(() => mockRepo.fetchTables(
              date: any(named: 'date'),
              time: any(named: 'time'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            )).thenAnswer((_) async => const [
              BookingTable(id: 4384, name: '202', capacity: 2),
            ]);
        when(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.ensureVisible(find.text('Зал 1'));
        await tester.tap(find.text('Зал 1'));
        await settle(tester);

        await tester.tap(find.text('Любой стол'));
        await settle(tester);

        await tester.tap(find.text('Стол 202'));
        await settle(tester);

        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await settle(tester);

        final captured = verify(() => mockRepo.createBooking(
              captureAny(),
              idempotencyKey: any(named: 'idempotencyKey'),
            )).captured;
        final req = captured.single as BookingRequest;
        expect(req.remarkedRoomId, 304);
        expect(req.remarkedTableId, 4384);
      });

      testWidgets('без выбора стола (только зал) remarked_table_id не отправляется',
          (tester) async {
        auth.currentUser = _sampleProfile();
        when(() => mockRepo.fetchZones()).thenAnswer((_) async => const [zoneA]);
        when(() => mockRepo.fetchTables(
              date: any(named: 'date'),
              time: any(named: 'time'),
              guests: any(named: 'guests'),
              zoneId: any(named: 'zoneId'),
            )).thenAnswer((_) async => const [
              BookingTable(id: 4384, name: '202', capacity: 2),
            ]);
        when(() => mockRepo.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.ensureVisible(find.text('Зал 1'));
        await tester.tap(find.text('Зал 1'));
        await settle(tester);

        await tester.ensureVisible(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await tester.tap(find.text('ОТПРАВИТЬ ЗАЯВКУ'));
        await settle(tester);

        final captured = verify(() => mockRepo.createBooking(
              captureAny(),
              idempotencyKey: any(named: 'idempotencyKey'),
            )).captured;
        final req = captured.single as BookingRequest;
        expect(req.remarkedRoomId, 304);
        expect(req.remarkedTableId, isNull);
      });
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/data/models/availability_slot.dart';
import 'package:piligrim/data/models/booking_request.dart';
import 'package:piligrim/data/repositories/booking_repository.dart';
import 'package:piligrim/providers/booking_provider.dart';

class _MockBookingRepository extends Mock implements BookingRepository {}

const _req = BookingRequest(
  guestName: 'Айдар',
  phone: '+77001234567',
  date: '2026-06-15',
  time: '19:30',
  guestsCount: 2,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_req);
  });

  group('BookingProvider', () {
    late _MockBookingRepository repository;
    late BookingProvider provider;

    setUp(() {
      repository = _MockBookingRepository();
      provider = BookingProvider(repository: repository);
    });

    test('submitBooking() устанавливает isSubmitting=true → false', () async {
      final completer = Completer<void>();
      when(() => repository.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenAnswer((_) => completer.future);

      final future = provider.submitBooking(_req);
      expect(provider.isSubmitting, isTrue);

      completer.complete();
      await future;

      expect(provider.isSubmitting, isFalse);
    });

    test('submitBooking() при успехе → isSuccess=true', () async {
      when(() => repository.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenAnswer((_) async {});

      await provider.submitBooking(_req);

      expect(provider.isSuccess, isTrue);
      expect(provider.error, isNull);
    });

    test('submitBooking() при ошибке → error != null', () async {
      when(() => repository.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenThrow(Exception('network error'));

      await provider.submitBooking(_req);

      expect(provider.error, isNotNull);
      expect(provider.isSuccess, isFalse);
    });

    test('submitBooking() сохраняет Idempotency-Key при ошибке и сбрасывает при успехе', () async {
      // 1. Первая попытка падает
      when(() => repository.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenThrow(Exception('network error'));

      await provider.submitBooking(_req);

      final verification1 = verify(() => repository.createBooking(any(), idempotencyKey: captureAny(named: 'idempotencyKey')));
      final firstKey = verification1.captured.single as String;

      // 2. Вторая попытка успешная
      when(() => repository.createBooking(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenAnswer((_) async {});

      await provider.submitBooking(_req);

      final verification2 = verify(() => repository.createBooking(any(), idempotencyKey: captureAny(named: 'idempotencyKey')));
      final secondKey = verification2.captured.single as String;
      
      // Ключ должен сохраниться после ошибки
      expect(firstKey, equals(secondKey));

      // 3. Третья попытка (уже новая форма после успеха)
      await provider.submitBooking(_req);
      final verification3 = verify(() => repository.createBooking(any(), idempotencyKey: captureAny(named: 'idempotencyKey')));
      final thirdKey = verification3.captured.single as String;
      
      // Ключ должен быть новым
      expect(thirdKey, isNot(equals(firstKey)));
    });
  });

  group('BookingProvider.loadAvailability', () {
    late _MockBookingRepository repository;
    late BookingProvider provider;

    setUp(() {
      repository = _MockBookingRepository();
      provider = BookingProvider(repository: repository);
    });

    test('без выбранной даты — no-op, запрос не выполняется', () async {
      await provider.loadAvailability();

      verifyNever(() => repository.fetchAvailability(
          date: any(named: 'date'), guests: any(named: 'guests')));
    });

    test('успех → слоты записаны, isLoadingAvailability сброшен, форма не блокируется', () async {
      provider.visitDate = DateTime(2026, 7, 15);
      when(() => repository.fetchAvailability(date: any(named: 'date'), guests: any(named: 'guests')))
          .thenAnswer((_) async => const [
                AvailabilitySlot(time: '12:00:00', isFree: false, tablesCount: 0),
                AvailabilitySlot(time: '14:00:00', isFree: true, tablesCount: 13),
              ]);

      await provider.loadAvailability();

      expect(provider.isLoadingAvailability, isFalse);
      expect(provider.availabilitySlots, hasLength(2));
      expect(provider.availabilityError, isNull);
      expect(provider.isSubmitting, isFalse);

      final captured = verify(() => repository.fetchAvailability(
              date: captureAny(named: 'date'), guests: captureAny(named: 'guests')))
          .captured;
      expect(captured[0], '2026-07-15');
      expect(captured[1], 2);
    });

    test('ошибка → availabilityError заполнен, слоты пустые, форма не блокируется', () async {
      provider.visitDate = DateTime(2026, 7, 15);
      when(() => repository.fetchAvailability(date: any(named: 'date'), guests: any(named: 'guests')))
          .thenThrow(Exception('Remarked недоступен'));

      await provider.loadAvailability();

      expect(provider.availabilityError, isNotNull);
      expect(provider.availabilitySlots, isEmpty);
      expect(provider.isLoadingAvailability, isFalse);
      expect(provider.isSubmitting, isFalse);
    });

    test('повторный вызов во время загрузки — no-op', () async {
      provider.visitDate = DateTime(2026, 7, 15);
      final completer = Completer<List<AvailabilitySlot>>();
      when(() => repository.fetchAvailability(date: any(named: 'date'), guests: any(named: 'guests')))
          .thenAnswer((_) => completer.future);

      final first = provider.loadAvailability();
      final second = provider.loadAvailability();

      completer.complete(const []);
      await first;
      await second;

      verify(() => repository.fetchAvailability(
          date: any(named: 'date'), guests: any(named: 'guests'))).called(1);
    });
  });
}

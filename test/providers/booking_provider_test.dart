import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
      when(() => repository.createBooking(any()))
          .thenAnswer((_) => completer.future);

      final future = provider.submitBooking(_req);
      expect(provider.isSubmitting, isTrue);

      completer.complete();
      await future;

      expect(provider.isSubmitting, isFalse);
    });

    test('submitBooking() при успехе → isSuccess=true', () async {
      when(() => repository.createBooking(any())).thenAnswer((_) async {});

      await provider.submitBooking(_req);

      expect(provider.isSuccess, isTrue);
      expect(provider.error, isNull);
    });

    test('submitBooking() при ошибке → error != null', () async {
      when(() => repository.createBooking(any()))
          .thenThrow(Exception('network error'));

      await provider.submitBooking(_req);

      expect(provider.error, isNotNull);
      expect(provider.isSuccess, isFalse);
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_booking.dart';
import 'package:piligrim/data/models/availability_slot.dart';
import 'package:piligrim/data/models/booking_request.dart';
import 'package:piligrim/data/repositories/booking_repository.dart';

import '../../support/mock_dio_adapter.dart';

const _req = BookingRequest(
  guestName: 'Айдар',
  phone: '+77001234567',
  date: '2026-06-15',
  time: '19:30',
  guestsCount: 2,
  zone: 'main',
  comment: 'У окна',
);

Map<String, dynamic> _bookingJson(int id) => {
      'id': id,
      'guest_name': 'Айдар',
      'phone': '+77001234567',
      'date': '2026-06-15',
      'time': '19:30',
      'guests_count': 2,
      'zone': 'main',
      'status': 'pending',
    };

void main() {
  group('BookingRepository', () {
    late MockDioAdapter adapter;
    late BookingRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = BookingRepository(dio: createMockDio(adapter));
    });

    test('createBooking() отправляет POST с Idempotency-Key заголовком', () async {
      adapter.enqueue(201, _bookingJson(1));
      await repository.createBooking(_req, idempotencyKey: 'test-key');

      expect(adapter.captured, hasLength(1));
      final req = adapter.captured.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/bookings/'));
      expect(req.headers['Idempotency-Key'], isNotEmpty);
    });

    test('createBooking() body содержит корректные поля из BookingRequest', () async {
      adapter.enqueue(201, _bookingJson(1));
      await repository.createBooking(_req, idempotencyKey: 'test-key');

      final body = adapter.captured.single.data as Map<String, dynamic>;
      expect(body['guest_name'], 'Айдар');
      expect(body['phone'], '+77001234567');
      expect(body['date'], '2026-06-15');
      expect(body['time'], '19:30');
      expect(body['guests_count'], 2);
      expect(body['zone'], 'main');
    });

    test('createBooking() бросает исключение при 400 (validation error)', () async {
      adapter.enqueue(400, {'detail': 'Invalid date'});
      expect(repository.createBooking(_req, idempotencyKey: 'test-key'), throwsA(isA<DioException>()));
    });

    test('fetchHistory() возвращает список ApiBooking', () async {
      adapter.enqueue(200, {
        'results': [_bookingJson(1), _bookingJson(2)],
        'next': null,
      });

      final result = await repository.fetchHistory();
      expect(result, hasLength(2));
      expect(result.first, isA<ApiBooking>());
      expect(result.first.id, 1);
      expect(result.last.id, 2);
      expect(result.first.status, 'pending');
    });

    test('fetchAvailability() отправляет GET с query-параметрами date и guests', () async {
      adapter.enqueue(200, {
        'date': '2026-07-15',
        'guests_count': 2,
        'slots': [
          {'time': '12:00:00', 'is_free': false, 'tables_count': 0},
          {'time': '14:00:00', 'is_free': true, 'tables_count': 13},
        ],
      });

      final result = await repository.fetchAvailability(date: '2026-07-15', guests: 2);

      expect(adapter.captured, hasLength(1));
      final req = adapter.captured.single;
      expect(req.method, 'GET');
      expect(req.path, contains('/bookings/availability/'));
      expect(req.queryParameters['date'], '2026-07-15');
      expect(req.queryParameters['guests'], 2);

      expect(result, hasLength(2));
      expect(result.first, isA<AvailabilitySlot>());
      expect(result.first.time, '12:00:00');
      expect(result.first.isFree, false);
      expect(result.first.tablesCount, 0);
      expect(result.last.time, '14:00:00');
      expect(result.last.isFree, true);
      expect(result.last.tablesCount, 13);
    });

    test('fetchAvailability() бросает исключение при 503 (Remarked недоступен)', () async {
      adapter.enqueue(503, {'detail': 'Проверка занятости временно недоступна'});
      expect(
        repository.fetchAvailability(date: '2026-07-15', guests: 2),
        throwsA(isA<DioException>()),
      );
    });
  });
}

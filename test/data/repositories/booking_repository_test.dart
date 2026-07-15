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

    test('fetchAvailability() передаёт zone_id, если указан', () async {
      adapter.enqueue(200, {'date': '2026-07-15', 'guests_count': 2, 'slots': []});
      await repository.fetchAvailability(date: '2026-07-15', guests: 2, zoneId: 305);

      final req = adapter.captured.single;
      expect(req.queryParameters['zone_id'], 305);
    });

    test('fetchAvailability() без zoneId не отправляет zone_id', () async {
      adapter.enqueue(200, {'date': '2026-07-15', 'guests_count': 2, 'slots': []});
      await repository.fetchAvailability(date: '2026-07-15', guests: 2);

      final req = adapter.captured.single;
      expect(req.queryParameters.containsKey('zone_id'), isFalse);
    });

    test('fetchZones() возвращает список BookingZone', () async {
      adapter.enqueue(200, [
        {'id': 304, 'name': 'Зал 1'},
        {'id': 305, 'name': 'Зал 2'},
      ]);

      final result = await repository.fetchZones();

      expect(adapter.captured.single.path, contains('/bookings/zones/'));
      expect(result, hasLength(2));
      expect(result.first.id, 304);
      expect(result.first.name, 'Зал 1');
      expect(result.last.id, 305);
      expect(result.last.name, 'Зал 2');
    });

    test('fetchTables() отправляет GET с date, time, guests и zone_id', () async {
      adapter.enqueue(200, [
        {'id': 4384, 'name': '202', 'capacity': 2},
        {'id': 4391, 'name': '210', 'capacity': 2},
      ]);

      final result = await repository.fetchTables(
        date: '2026-07-15',
        time: '19:30:00',
        guests: 2,
        zoneId: 305,
      );

      expect(adapter.captured, hasLength(1));
      final req = adapter.captured.single;
      expect(req.method, 'GET');
      expect(req.path, contains('/bookings/tables/'));
      expect(req.queryParameters['date'], '2026-07-15');
      expect(req.queryParameters['time'], '19:30:00');
      expect(req.queryParameters['guests'], 2);
      expect(req.queryParameters['zone_id'], 305);

      expect(result, hasLength(2));
      expect(result.first.id, 4384);
      expect(result.first.name, '202');
      expect(result.first.capacity, 2);
      expect(result.last.id, 4391);
      expect(result.last.name, '210');
    });

    test('fetchTables() бросает исключение при 400', () async {
      adapter.enqueue(400, {'detail': 'Invalid params'});
      expect(
        repository.fetchTables(date: '2026-07-15', time: '19:30:00', guests: 2, zoneId: 305),
        throwsA(isA<DioException>()),
      );
    });
  });
}

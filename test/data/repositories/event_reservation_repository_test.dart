import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/repositories/event_reservation_repository.dart';

import '../../support/mock_dio_adapter.dart';

void main() {
  group('EventReservationRepository', () {
    late MockDioAdapter adapter;
    late EventReservationRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = EventReservationRepository(dio: createMockDio(adapter));
    });

    test('fetchMyReservationsCount returns results length', () async {
      adapter.enqueue(200, {
        'count': 2,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      });

      final count = await repository.fetchMyReservationsCount();
      expect(count, 2);
      expect(adapter.captured.single.path, '/events/reservations/my/');
    });

    test('fetchMyReservationsCount returns 0 for empty results', () async {
      adapter.enqueue(200, {'count': 0, 'results': []});

      expect(await repository.fetchMyReservationsCount(), 0);
    });
  });
}

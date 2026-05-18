import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/repositories/events_repository.dart';

import '../../support/mock_dio_adapter.dart';

Map<String, dynamic> _eventJson({required int id, bool isPast = false}) => {
      'id': id,
      'title': 'Событие $id',
      'description': 'Описание',
      'date_time': '2026-06-15T19:00:00.000Z',
      'format': 'open',
      'image': 'https://cdn/event$id.jpg',
      'price': 3000,
      'is_past': isPast,
    };

void main() {
  group('EventsRepository', () {
    late MockDioAdapter adapter;
    late EventsRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = EventsRepository(dio: createMockDio(adapter));
    });

    test('fetchUpcoming parses paginated results', () async {
      adapter.enqueue(200, {
        'results': [_eventJson(id: 1)],
        'next': null,
      });

      final events = await repository.fetchUpcoming();
      expect(events, hasLength(1));
      expect(events.first, isA<ApiEvent>());
      expect(events.first.coverUrl, 'https://cdn/event1.jpg');
      expect(events.first.isPast, isFalse);
    });

    test('fetchArchived marks events as past', () async {
      adapter.enqueue(200, {
        'results': [_eventJson(id: 2, isPast: true)],
        'next': null,
      });

      final events = await repository.fetchArchived();
      expect(events.single.isPast, isTrue);
    });

    test('fetchNews parses posts', () async {
      adapter.enqueue(200, {
        'results': [
          {
            'id': 5,
            'title': 'Новость',
            'content': 'Текст',
            'created_at': '2026-05-01T10:00:00Z',
          },
        ],
        'next': null,
      });

      final news = await repository.fetchNews();
      expect(news, hasLength(1));
      expect(news.first.title, 'Новость');
    });

    test('createReservation sends event, guests and idempotency key', () async {
      adapter.enqueue(201, {'id': 99});
      await repository.createReservation(eventId: 7, guestsCount: 2);

      expect(adapter.captured, hasLength(1));
      final req = adapter.captured.single;
      expect(req.path, contains('/events/reservations/create/'));
      expect(req.data, {'event': 7, 'guests_count': 2});
      expect(req.headers['Idempotency-Key'], isNotEmpty);
    });

    test('fetchUpcoming throws on 500', () async {
      adapter.enqueue(500, {'detail': 'error'});
      expect(repository.fetchUpcoming(), throwsA(isA<DioException>()));
    });
  });
}

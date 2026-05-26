import 'dart:io';

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

Map<String, dynamic> _newsJson({required int id}) => {
      'id': id,
      'title': 'Новость $id',
      'content': 'Текст новости',
      'created_at': '2026-05-01T10:00:00Z',
    };

Future<File> _createTempFile(String name) async {
  final file = File('${Directory.systemTemp.path}/$name');
  // Минимальный JPEG-заголовок, чтобы файл не был пустым
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
  return file;
}

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
      await repository.createReservation(eventId: 7, guestsCount: 2, idempotencyKey: 'test-key');

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

    // ─── Admin: Events ──────────────────────────────────────────────────────────

    group('Admin Events', () {
      test('fetchAdminEvents returns list including isActive=false', () async {
        adapter.enqueue(200, [
          _eventJson(id: 10),
          {
            ..._eventJson(id: 11),
            'is_active': false,
          },
        ]);

        final events = await repository.fetchAdminEvents();
        expect(events, hasLength(2));
        expect(events[0].isActive, isTrue);
        expect(events[1].isActive, isFalse);
      });

      test('createEvent sends multipart with image', () async {
        adapter.enqueue(201, _eventJson(id: 20));
        final tmpFile = await _createTempFile('event_cover.jpg');

        await repository.createEvent(
          {'title': 'Новое событие', 'format': 'open'},
          image: tmpFile,
        );

        final req = adapter.captured.single;
        expect(req.path, contains('/events/admin/events/'));
        expect(req.data, isA<FormData>());
        final form = req.data as FormData;
        expect(form.files.any((e) => e.key == 'image'), isTrue);

        await tmpFile.delete();
      });

      test('createEvent without image sends FormData without image key', () async {
        adapter.enqueue(201, _eventJson(id: 21));

        await repository.createEvent({'title': 'Событие', 'format': 'open'});

        final req = adapter.captured.single;
        expect(req.data, isA<FormData>());
        final form = req.data as FormData;
        expect(form.files.any((e) => e.key == 'image'), isFalse);
      });

      test('updateEvent with image sends PATCH multipart', () async {
        adapter.enqueue(200, _eventJson(id: 5));
        final tmpFile = await _createTempFile('updated_cover.jpg');

        await repository.updateEvent(5, {'title': 'Обновлено'}, image: tmpFile);

        final req = adapter.captured.single;
        expect(req.method, 'PATCH');
        expect(req.path, contains('/events/admin/events/5/'));
        expect(req.data, isA<FormData>());
        final form = req.data as FormData;
        expect(form.files.any((e) => e.key == 'image'), isTrue);

        await tmpFile.delete();
      });

      test('updateEvent without image sends PATCH JSON body', () async {
        adapter.enqueue(200, _eventJson(id: 5));

        await repository.updateEvent(5, {'title': 'Обновлено'});

        final req = adapter.captured.single;
        expect(req.method, 'PATCH');
        expect(req.path, contains('/events/admin/events/5/'));
        expect(req.data, isNot(isA<FormData>()));
        expect((req.data as Map<String, dynamic>)['title'], 'Обновлено');
      });

      test('deleteEvent calls DELETE on correct URL', () async {
        adapter.enqueue(204, null);

        await repository.deleteEvent(5);

        final req = adapter.captured.single;
        expect(req.method, 'DELETE');
        expect(req.path, contains('/events/admin/events/5/'));
      });
    });

    // ─── Admin: News ────────────────────────────────────────────────────────────

    group('Admin News', () {
      test('fetchAdminNews returns list', () async {
        adapter.enqueue(200, [_newsJson(id: 1)]);

        final news = await repository.fetchAdminNews();
        expect(news, hasLength(1));
        expect(news.first.title, 'Новость 1');
      });

      test('createNews without image sends FormData', () async {
        adapter.enqueue(201, _newsJson(id: 10));

        await repository.createNews({'title': 'Новость', 'content': 'Текст'});

        final req = adapter.captured.single;
        expect(req.path, contains('/events/admin/news/'));
        expect(req.data, isA<FormData>());
        final form = req.data as FormData;
        expect(form.files.any((e) => e.key == 'image'), isFalse);
      });

      test('deleteNews calls DELETE on correct URL', () async {
        adapter.enqueue(204, null);

        await repository.deleteNews(3);

        final req = adapter.captured.single;
        expect(req.method, 'DELETE');
        expect(req.path, contains('/events/admin/news/3/'));
      });
    });
  });
}

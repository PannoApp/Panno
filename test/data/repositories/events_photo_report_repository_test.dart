import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_event_photo.dart';
import 'package:piligrim/data/repositories/events_repository.dart';

import '../../support/mock_dio_adapter.dart';

void main() {
  group('EventsRepository.fetchPhotoReport', () {
    late MockDioAdapter adapter;
    late EventsRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = EventsRepository(dio: createMockDio(adapter));
    });

    test('parses list of photos', () async {
      adapter.enqueue(200, [
        {'id': 1, 'image': 'https://cdn/r1.jpg', 'order': 0},
        {'id': 2, 'image': 'https://cdn/r2.jpg', 'order': 1},
      ]);

      final photos = await repository.fetchPhotoReport(42);

      expect(photos, hasLength(2));
      expect(photos.first, isA<ApiEventPhoto>());
      expect(photos.first.id, 1);
      expect(photos.first.imageUrl, 'https://cdn/r1.jpg');
      expect(photos.first.order, 0);
    });

    test('returns empty list for empty array', () async {
      adapter.enqueue(200, <dynamic>[]);

      final photos = await repository.fetchPhotoReport(99);

      expect(photos, isEmpty);
    });

    test('uses correct endpoint', () async {
      adapter.enqueue(200, <dynamic>[]);

      await repository.fetchPhotoReport(7);

      expect(adapter.captured.single.path, contains('/events/7/photo-report/'));
    });

    test('throws DioException on 500', () async {
      adapter.enqueue(500, {'detail': 'error'});

      expect(
        () => repository.fetchPhotoReport(1),
        throwsA(isA<DioException>()),
      );
    });
  });
}

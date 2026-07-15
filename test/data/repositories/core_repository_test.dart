import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/core_info.dart';
import 'package:piligrim/data/repositories/core_repository.dart';

import '../../support/mock_dio_adapter.dart';

void main() {
  group('CoreRepository', () {
    late MockDioAdapter adapter;
    late CoreRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = CoreRepository(dio: createMockDio(adapter));
    });

    test('fetchCoreInfo returns CoreInfo on 200', () async {
      adapter.enqueue(200, {
        'address': 'Алматы',
        'working_hours': '12:00–23:00',
        'is_open_now': true,
        'phone': '+77001234567',
        'whatsapp': '+77001234567',
        'hero_slides': [
          {'id': 1, 'image': 'https://cdn/slide.jpg', 'order': 0},
        ],
        'visit_rules': 'Правила',
        'privacy_policy': 'Политика',
      });

      final info = await repository.fetchCoreInfo();
      expect(info, isA<CoreInfo>());
      expect(info.isOpenNow, isTrue);
      expect(info.heroImageUrls, ['https://cdn/slide.jpg']);
    });

    test('fetchCoreInfo throws on 500', () async {
      adapter.enqueue(500, {'detail': 'error'});
      expect(repository.fetchCoreInfo(), throwsA(isA<DioException>()));
    });

    test('fetchInterior returns InteriorSlide list', () async {
      adapter.enqueue(200, [
        {
          'id': 1,
          'zone': 'main_hall',
          'zone_display': 'Зал',
          'image': 'https://cdn/hall.jpg',
          'order': 1,
        },
      ]);

      final slides = await repository.fetchInterior();
      expect(slides, hasLength(1));
      expect(slides.first.imageUrl, 'https://cdn/hall.jpg');
    });

    test('fetchAppVersion parses versions', () async {
      adapter.enqueue(200, {
        'platform': 'ios',
        'min_version': '1.0.0',
        'latest_version': '1.3.0',
        'store_url': 'https://apps.apple.com/app',
      });

      final v = await repository.fetchAppVersion('ios');
      expect(v.minVersion, '1.0.0');
      expect(v.latestVersion, '1.3.0');
      expect(v.storeUrl, contains('apple.com'));
    });
  });
}

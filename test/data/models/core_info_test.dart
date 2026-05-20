import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/core_info.dart';

Map<String, dynamic> _minimalCoreInfoJson() => {
      'address': 'Астана',
      'working_hours': '12:00–23:00',
      'is_open_now': true,
      'phone': '+77001234567',
      'privacy_policy': 'Политика',
      'booking_deposit_required': false,
    };

void main() {
  group('CoreInfo.fromJson', () {
    test('parses six new link fields when present', () {
      final info = CoreInfo.fromJson({
        ..._minimalCoreInfoJson(),
        'twogis_link': 'https://2gis.kz/firm/1',
        'google_maps_link': 'https://maps.google.com/?q=1',
        'yandex_maps_link': 'https://yandex.kz/maps/1',
        'feedback_url': 'https://wa.me/77001234567',
        'terms_of_service': 'Текст соглашения',
        'tour_link': 'https://tour.example.com',
      });

      expect(info.twogisLink, 'https://2gis.kz/firm/1');
      expect(info.googleMapsLink, 'https://maps.google.com/?q=1');
      expect(info.yandexMapsLink, 'https://yandex.kz/maps/1');
      expect(info.feedbackUrl, 'https://wa.me/77001234567');
      expect(info.termsOfService, 'Текст соглашения');
      expect(info.tourLink, 'https://tour.example.com');
    });

    test('new fields are null when absent from JSON', () {
      final info = CoreInfo.fromJson(_minimalCoreInfoJson());

      expect(info.twogisLink, isNull);
      expect(info.googleMapsLink, isNull);
      expect(info.yandexMapsLink, isNull);
      expect(info.feedbackUrl, isNull);
      expect(info.termsOfService, isNull);
      expect(info.tourLink, isNull);
    });

    test('supports camelCase keys for new fields', () {
      final info = CoreInfo.fromJson({
        ..._minimalCoreInfoJson(),
        'twogisLink': 'https://2gis.kz/camel',
        'feedbackUrl': 'https://feedback.test',
      });

      expect(info.twogisLink, 'https://2gis.kz/camel');
      expect(info.feedbackUrl, 'https://feedback.test');
    });

    test('existing fields still parse correctly', () {
      final info = CoreInfo.fromJson({
        ..._minimalCoreInfoJson(),
        'visit_rules': [
          {'title': 'Дресс-код', 'body': 'Smart casual'},
        ],
        'hero_slides': [
          {'id': 1, 'image': 'https://cdn/hero.jpg', 'order': 0},
        ],
      });

      expect(info.address, 'Астана');
      expect(info.isOpenNow, isTrue);
      expect(info.privacyPolicy, 'Политика');
      expect(info.visitRules, hasLength(1));
      expect(info.heroImageUrls, ['https://cdn/hero.jpg']);
    });

    test('toJson includes new fields when set', () {
      final info = CoreInfo.fromJson({
        ..._minimalCoreInfoJson(),
        'twogis_link': 'https://2gis.kz/out',
      });

      final json = info.toJson();
      expect(json['twogis_link'], 'https://2gis.kz/out');
      expect(json.containsKey('tour_link'), isFalse);
    });
  });
}

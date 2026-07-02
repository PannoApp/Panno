import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/events_news_data.dart';
import 'package:piligrim/data/models/api_event.dart';

Map<String, dynamic> _base(Map<String, dynamic> overrides) => {
      'id': 1,
      'title': 'Блюдо',
      'description': '',
      'starts_at': '2026-01-01T12:00:00Z',
      'format': 'open',
      'is_past': false,
      ...overrides,
    };

void main() {
  group('ApiEvent.fromJson', () {
    test('parses startsAt as DateTime', () {
      final event = ApiEvent.fromJson({
        'id': 10,
        'title': 'Вечер джаза',
        'description': 'Живой звук',
        'starts_at': '2026-06-15T19:00:00.000Z',
        'format': 'open',
        'price': '5000',
        'is_past': false,
      });

      expect(event.startsAt, DateTime.parse('2026-06-15T19:00:00.000Z'));
      expect(event.priceFrom, 5000);
    });

    // --- Тесты парсинга десятичной цены ---

    test('price "3500.00" (строка-десятичная) → priceFrom == 3500', () {
      final event = ApiEvent.fromJson(_base({'price': '3500.00'}));
      expect(event.priceFrom, 3500);
    });

    test('price "0.00" → priceFrom == 0', () {
      final event = ApiEvent.fromJson(_base({'price': '0.00'}));
      expect(event.priceFrom, 0);
    });

    test('price null → priceFrom == null', () {
      final event = ApiEvent.fromJson(_base({'price': null}));
      expect(event.priceFrom, isNull);
    });

    test('price int 3500 → priceFrom == 3500', () {
      final event = ApiEvent.fromJson(_base({'price': 3500}));
      expect(event.priceFrom, 3500);
    });

    test('поле price отсутствует → priceFrom == null', () {
      final event = ApiEvent.fromJson(_base({}));
      expect(event.priceFrom, isNull);
    });

    test('recognizes format open and closed', () {
      final open = ApiEvent.fromJson({
        'id': 1,
        'title': 'A',
        'description': 'd',
        'starts_at': '2026-01-01T12:00:00Z',
        'format': 'open',
        'is_past': false,
      });
      final closed = ApiEvent.fromJson({
        'id': 2,
        'title': 'B',
        'description': 'd',
        'starts_at': '2026-01-01T12:00:00Z',
        'format': 'closed',
        'is_past': true,
      });

      expect(open.format, ApiEventFormat.open);
      expect(closed.format, ApiEventFormat.closed);
      expect(closed.isPast, isTrue);
    });

    // --- Тесты лимита мест (вместимости) ---

    test('дефолтные значения maxPlaces и occupiedPlaces равны 0', () {
      final event = ApiEvent.fromJson(_base({}));
      expect(event.maxPlaces, 0);
      expect(event.occupiedPlaces, 0);
    });

    test('парсинг max_places и occupied_places из JSON', () {
      final event = ApiEvent.fromJson(_base({
        'max_places': 50,
        'occupied_places': 12,
      }));
      expect(event.maxPlaces, 50);
      expect(event.occupiedPlaces, 12);
    });

    test('сериализация toJson содержит max_places и occupied_places', () {
      final event = ApiEvent(
        id: 1,
        title: 'Тест',
        description: 'd',
        startsAt: DateTime.parse('2026-01-01T12:00:00Z'),
        format: ApiEventFormat.open,
        isPast: false,
        maxPlaces: 40,
        occupiedPlaces: 10,
      );
      final json = event.toJson();
      expect(json['max_places'], 40);
      expect(json['occupied_places'], 10);
    });

    // --- TICKET-031-T: тесты поля isActive ---

    test('fromJson: is_active: true → isActive == true', () {
      final event = ApiEvent.fromJson(_base({'is_active': true}));
      expect(event.isActive, isTrue);
    });

    test('fromJson: is_active: false → isActive == false', () {
      final event = ApiEvent.fromJson(_base({'is_active': false}));
      expect(event.isActive, isFalse);
    });

    test('fromJson: поле is_active отсутствует → isActive по умолчанию true', () {
      final event = ApiEvent.fromJson(_base({}));
      expect(event.isActive, isTrue);
    });

    test('toJson содержит is_active', () {
      final event = ApiEvent(
        id: 1,
        title: 'Тест',
        description: 'd',
        startsAt: DateTime.parse('2026-01-01T12:00:00Z'),
        format: ApiEventFormat.open,
        isPast: false,
        isActive: false,
      );
      expect(event.toJson()['is_active'], isFalse);
    });
  });

  // --- TICKET-031-T: тесты PiligrimNewsPost.numericId ---

  group('PiligrimNewsPost.numericId', () {
    Map<String, dynamic> newsBase(Map<String, dynamic> overrides) => {
          'title': 'Новость',
          'content': 'Текст',
          'created_at': '2026-01-01T10:00:00Z',
          ...overrides,
        };

    test('fromJson: id == 5 → numericId == 5', () {
      final post = PiligrimNewsPost.fromJson(newsBase({'id': 5}));
      expect(post.numericId, 5);
    });

    test('fromJson: id как строка "42" → numericId == 42', () {
      final post = PiligrimNewsPost.fromJson(newsBase({'id': 42}));
      expect(post.numericId, 42);
    });
  });
}

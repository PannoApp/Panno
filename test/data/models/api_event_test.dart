import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_event.dart';

void main() {
  group('ApiEvent.fromJson', () {
    test('parses startsAt as DateTime', () {
      final event = ApiEvent.fromJson({
        'id': 10,
        'title': 'Вечер джаза',
        'description': 'Живой звук',
        'starts_at': '2026-06-15T19:00:00.000Z',
        'format': 'open',
        'price_from': '5000',
        'is_past': false,
      });

      expect(event.startsAt, DateTime.parse('2026-06-15T19:00:00.000Z'));
      expect(event.priceFrom, 5000);
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
  });
}

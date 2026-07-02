// TICKET-031-T
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/events_news_data.dart';

Map<String, dynamic> _baseEventJson({Map<String, dynamic> overrides = const {}}) {
  return {
    'id': 1,
    'title': 'Test Event',
    'description': 'Description',
    'starts_at': '2026-06-01T18:00:00Z',
    'format': 'open',
    ...overrides,
  };
}

void main() {
  group('ApiEvent.fromJson — isActive', () {
    test('test_fromJson_includes_is_active_true', () {
      final event = ApiEvent.fromJson(_baseEventJson(overrides: {'is_active': true}));
      expect(event.isActive, isTrue);
    });

    test('test_fromJson_includes_is_active_false', () {
      final event = ApiEvent.fromJson(_baseEventJson(overrides: {'is_active': false}));
      expect(event.isActive, isFalse);
    });

    test('test_fromJson_is_active_defaults_to_true', () {
      final event = ApiEvent.fromJson(_baseEventJson());
      expect(event.isActive, isTrue);
    });

    test('toJson includes is_active', () {
      final event = ApiEvent.fromJson(_baseEventJson(overrides: {'is_active': false}));
      expect(event.toJson()['is_active'], isFalse);
    });
  });

  group('PiligrimNewsPost.numericId', () {
    test('test_news_numeric_id_parsed', () {
      final post = PiligrimNewsPost.fromJson({
        'id': 5,
        'title': 'News Title',
        'content': 'Body text',
        'created_at': '2026-05-01T10:00:00Z',
      });
      expect(post.numericId, equals(5));
    });

    test('numericId returns 0 for unparseable id', () {
      final post = PiligrimNewsPost(
        id: 'abc',
        title: 'Title',
        body: 'Body',
        publishedAt: DateTime(2026),
      );
      expect(post.numericId, equals(0));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/booking_request.dart';

void main() {
  group('BookingRequest.toJson', () {
    test('builds POST body with required fields', () {
      final json = const BookingRequest(
        guestName: 'Айдар',
        phone: '+77001234567',
        date: '2026-05-20',
        time: '19:30',
        guestsCount: 4,
        zone: 'зал',
        comment: 'у окна',
      ).toJson();

      expect(json, {
        'guest_name': 'Айдар',
        'phone': '+77001234567',
        'date': '2026-05-20',
        'time': '19:30',
        'guests_count': 4,
        'zone': 'зал',
        'comment': 'у окна',
      });
    });

    test('omits null zone, remarkedRoomId and comment', () {
      final json = const BookingRequest(
        guestName: 'Айдар',
        phone: '+77001234567',
        date: '2026-05-20',
        time: '19:30',
        guestsCount: 2,
      ).toJson();

      expect(json.containsKey('zone'), isFalse);
      expect(json.containsKey('remarked_room_id'), isFalse);
      expect(json.containsKey('comment'), isFalse);
      expect(json['guests_count'], 2);
    });

    test('includes remarked_room_id when zone selected', () {
      final json = const BookingRequest(
        guestName: 'Айдар',
        phone: '+77001234567',
        date: '2026-05-20',
        time: '19:30',
        guestsCount: 4,
        zone: 'Зал 1',
        remarkedRoomId: 304,
      ).toJson();

      expect(json['zone'], 'Зал 1');
      expect(json['remarked_room_id'], 304);
    });
  });
}

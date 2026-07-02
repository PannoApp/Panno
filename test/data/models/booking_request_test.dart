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

    test('omits null zone and comment', () {
      final json = const BookingRequest(
        guestName: 'Айдар',
        phone: '+77001234567',
        date: '2026-05-20',
        time: '19:30',
        guestsCount: 2,
      ).toJson();

      expect(json.containsKey('zone'), isFalse);
      expect(json.containsKey('comment'), isFalse);
      expect(json['guests_count'], 2);
    });
  });
}

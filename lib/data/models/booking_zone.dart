import 'json_utils.dart';

/// Реальный зал ресторана из Remarked (GET /bookings/zones/), а не
/// придуманный набор main/terrace/private.
class BookingZone {
  const BookingZone({required this.id, required this.name});

  final int id;
  final String name;

  factory BookingZone.fromJson(Map<String, dynamic> json) {
    return BookingZone(
      id: parseInt(json['id'], field: 'id'),
      name: parseString(json['name'], field: 'name'),
    );
  }
}

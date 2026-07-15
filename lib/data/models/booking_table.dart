import 'json_utils.dart';

/// Свободный стол конкретного зала на точные дату/время/кол-во гостей
/// (GET /bookings/tables/) — для пикера конкретного стола, появляющегося
/// после выбора зала (см. BookingZone).
class BookingTable {
  const BookingTable({required this.id, this.name, this.capacity});

  final int id;
  final String? name;
  final int? capacity;

  factory BookingTable.fromJson(Map<String, dynamic> json) {
    return BookingTable(
      id: parseInt(json['id'], field: 'id'),
      name: parseStringOrNull(json['name']),
      capacity: parseIntOrNull(json['capacity']),
    );
  }
}

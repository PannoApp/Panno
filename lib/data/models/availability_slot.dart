import 'json_utils.dart';

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.time,
    required this.isFree,
    required this.tablesCount,
  });

  final String time;
  final bool isFree;
  final int tablesCount;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      time: parseString(json['time'], field: 'time'),
      isFree: parseBool(json['is_free']),
      tablesCount: parseInt(json['tables_count'], field: 'tables_count'),
    );
  }
}

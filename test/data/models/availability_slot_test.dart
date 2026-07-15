import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/availability_slot.dart';

void main() {
  group('AvailabilitySlot.fromJson', () {
    test('parses all fields (свободный слот)', () {
      final slot = AvailabilitySlot.fromJson({
        'time': '14:00:00',
        'is_free': true,
        'tables_count': 13,
      });

      expect(slot.time, '14:00:00');
      expect(slot.isFree, true);
      expect(slot.tablesCount, 13);
    });

    test('parses all fields (занятый слот)', () {
      final slot = AvailabilitySlot.fromJson({
        'time': '12:00:00',
        'is_free': false,
        'tables_count': 0,
      });

      expect(slot.time, '12:00:00');
      expect(slot.isFree, false);
      expect(slot.tablesCount, 0);
    });

    test('бросает FormatException при отсутствующем поле time', () {
      expect(
        () => AvailabilitySlot.fromJson({
          'is_free': true,
          'tables_count': 5,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('бросает FormatException при отсутствующем поле tables_count', () {
      expect(
        () => AvailabilitySlot.fromJson({
          'time': '14:00:00',
          'is_free': true,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

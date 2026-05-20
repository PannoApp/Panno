import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('notifications_enabled false when set', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'notifications_enabled': false,
      });

      expect(profile.notificationsEnabled, isFalse);
    });

    test('notifications_enabled defaults to true when absent', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.notificationsEnabled, isTrue);
    });

    test('date_joined parses to DateTime', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'date_joined': '2024-03-15T10:00:00Z',
      });

      expect(profile.dateJoined, isNotNull);
      expect(profile.dateJoined!.year, 2024);
      expect(profile.dateJoined!.month, 3);
    });

    test('toJson includes notifications_enabled', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'notifications_enabled': false,
      });

      expect(profile.toJson()['notifications_enabled'], isFalse);
    });
  });
}

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

    test('fromJson with is_staff true and role admin', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'is_staff': true,
        'role': 'admin',
      });

      expect(profile.isStaff, isTrue);
      expect(profile.isAdmin, isTrue);
      expect(profile.role, 'admin');
    });

    test('fromJson regular user has isAdmin false', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'is_staff': false,
        'role': '',
      });

      expect(profile.isAdmin, isFalse);
    });

    test('fromJson missing is_staff and role defaults without crash', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.isStaff, isFalse);
      expect(profile.role, '');
      expect(profile.isAdmin, isFalse);
    });

    test('copyWith preserves isStaff when unrelated fields change', () {
      final original = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'is_staff': true,
        'role': 'staff',
      });

      final updated = original.copyWith(notifyEvents: false);

      expect(updated.isStaff, isTrue);
      expect(updated.role, 'staff');
      expect(updated.notifyEvents, isFalse);
    });
  });
}

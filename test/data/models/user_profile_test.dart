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

    test('gender defaults to notSpecified when absent', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.gender, UserGender.notSpecified);
    });

    test('gender parses male/female from backend values', () {
      final male = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'gender': 'male',
      });
      final female = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'gender': 'female',
      });

      expect(male.gender, UserGender.male);
      expect(female.gender, UserGender.female);
    });

    test('email defaults to empty string when absent', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.email, '');
    });

    test('birthday parses YYYY-MM-DD to DateTime', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'birthday': '1995-05-20',
      });

      expect(profile.birthday, isNotNull);
      expect(profile.birthday!.year, 1995);
      expect(profile.birthday!.month, 5);
      expect(profile.birthday!.day, 20);
    });

    test('birthday is null when absent', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.birthday, isNull);
    });

    test('toJson round-trips gender, email and birthday', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'gender': 'female',
        'email': 'a@example.com',
        'birthday': '1995-05-20',
      });

      final json = profile.toJson();
      expect(json['gender'], 'female');
      expect(json['email'], 'a@example.com');
      expect(json['birthday'], '1995-05-20');
    });

    test('toJson omits birthday when null', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.toJson().containsKey('birthday'), isFalse);
    });

    test('cashback defaults to 0 when absent', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      expect(profile.cashback, 0);
    });

    test('cashback parses numeric string from Decimal field', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'cashback': '1250.50',
      });

      expect(profile.cashback, 1250.5);
    });

    test('copyWith preserves cashback', () {
      final original = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
        'cashback': '400',
      });

      final updated = original.copyWith(notifyEvents: false);

      expect(updated.cashback, 400);
    });

    test('copyWith updates gender/email/birthday independently', () {
      final original = UserProfile.fromJson({
        'id': 1,
        'phone': '+77001234567',
        'first_name': 'A',
        'last_name': 'B',
      });

      final updated = original.copyWith(
        gender: UserGender.male,
        email: 'new@example.com',
        birthday: DateTime(1990, 1, 1),
      );

      expect(updated.gender, UserGender.male);
      expect(updated.email, 'new@example.com');
      expect(updated.birthday, DateTime(1990, 1, 1));
      // Остальное не тронуто
      expect(updated.firstName, 'A');
    });
  });
}

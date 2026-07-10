import 'json_utils.dart';

/// Пол гостя — зеркалит `User.GENDER_CHOICES` на бэкенде (male/female/not_specified).
enum UserGender { male, female, notSpecified }

extension UserGenderJson on UserGender {
  /// Значение, которое ожидает `gender` в `GET`/`PATCH /users/profile/`.
  String toJsonValue() {
    switch (this) {
      case UserGender.male:
        return 'male';
      case UserGender.female:
        return 'female';
      case UserGender.notSpecified:
        return 'not_specified';
    }
  }

  /// Подпись для UI (онбординг, профиль).
  String get label {
    switch (this) {
      case UserGender.male:
        return 'Мужской';
      case UserGender.female:
        return 'Женский';
      case UserGender.notSpecified:
        return 'Не указан';
    }
  }
}

UserGender _parseGender(dynamic value) {
  final raw = value?.toString().toLowerCase().trim() ?? '';
  switch (raw) {
    case 'male':
      return UserGender.male;
    case 'female':
      return UserGender.female;
    default:
      return UserGender.notSpecified;
  }
}

/// Форматирует дату как `YYYY-MM-DD` — формат, который ожидает бэкенд для `birthday`.
String formatDateOnly(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$mm-$dd';
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.notifyEvents,
    required this.notifyPromotions,
    required this.notifyClosedEvents,
    required this.notificationsEnabled,
    this.dateJoined,
    this.isStaff = false,
    this.role = '',
    this.gender = UserGender.notSpecified,
    this.email = '',
    this.birthday,
    this.cashback = 0,
  });

  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final bool notifyEvents;
  final bool notifyPromotions;
  final bool notifyClosedEvents;
  final bool notificationsEnabled;
  final DateTime? dateJoined;
  final bool isStaff;
  final String role;
  final UserGender gender;
  final String email;
  final DateTime? birthday;
  final double cashback;

  String get displayName => '$firstName $lastName'.trim();
  bool get isAdmin => isStaff;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: parseInt(json['id'], field: 'id'),
      phone: parseString(json['phone'], field: 'phone'),
      firstName: parseString(json['first_name'] ?? json['firstName'], field: 'first_name'),
      lastName: parseString(json['last_name'] ?? json['lastName'], field: 'last_name'),
      notifyEvents: parseBool(
        json['notify_events'] ?? json['notifyEvents'],
        defaultValue: true,
      ),
      notifyPromotions: parseBool(
        json['notify_promotions'] ?? json['notifyPromotions'],
      ),
      notifyClosedEvents: parseBool(
        json['notify_closed_events'] ?? json['notifyClosedEvents'],
      ),
      notificationsEnabled: parseBool(
        json['notifications_enabled'] ?? json['notificationsEnabled'],
        defaultValue: true,
      ),
      dateJoined: _parseDateJoined(json['date_joined'] ?? json['dateJoined']),
      isStaff: json['is_staff'] as bool? ?? false,
      role: json['role'] as String? ?? '',
      gender: _parseGender(json['gender']),
      email: (json['email'] ?? '').toString(),
      birthday: _parseDateJoined(json['birthday']),
      cashback: json['cashback'] == null ? 0 : parseDouble(json['cashback'], field: 'cashback'),
    );
  }

  static DateTime? _parseDateJoined(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'notify_events': notifyEvents,
        'notify_promotions': notifyPromotions,
        'notify_closed_events': notifyClosedEvents,
        'notifications_enabled': notificationsEnabled,
        if (dateJoined != null) 'date_joined': dateJoined!.toIso8601String(),
        'is_staff': isStaff,
        'role': role,
        'gender': gender.toJsonValue(),
        'email': email,
        if (birthday != null) 'birthday': formatDateOnly(birthday!),
        'cashback': cashback,
      };

  UserProfile copyWith({
    bool? notifyEvents,
    bool? notifyPromotions,
    bool? notifyClosedEvents,
    bool? notificationsEnabled,
    DateTime? dateJoined,
    bool? isStaff,
    String? role,
    String? firstName,
    String? lastName,
    UserGender? gender,
    String? email,
    DateTime? birthday,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      notifyEvents: notifyEvents ?? this.notifyEvents,
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifyClosedEvents: notifyClosedEvents ?? this.notifyClosedEvents,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dateJoined: dateJoined ?? this.dateJoined,
      isStaff: isStaff ?? this.isStaff,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      birthday: birthday ?? this.birthday,
      cashback: cashback,
    );
  }
}

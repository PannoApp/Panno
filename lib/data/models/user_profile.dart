import 'json_utils.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.notifyEvents,
    required this.notifyPromotions,
    required this.notifyClosedEvents,
  });

  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final bool notifyEvents;
  final bool notifyPromotions;
  final bool notifyClosedEvents;

  String get displayName => '$firstName $lastName'.trim();

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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'notify_events': notifyEvents,
        'notify_promotions': notifyPromotions,
        'notify_closed_events': notifyClosedEvents,
      };

  UserProfile copyWith({
    bool? notifyEvents,
    bool? notifyPromotions,
    bool? notifyClosedEvents,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      notifyEvents: notifyEvents ?? this.notifyEvents,
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifyClosedEvents: notifyClosedEvents ?? this.notifyClosedEvents,
    );
  }
}

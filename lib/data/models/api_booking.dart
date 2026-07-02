import 'json_utils.dart';

class ApiBooking {
  const ApiBooking({
    required this.id,
    required this.guestName,
    required this.phone,
    required this.date,
    required this.time,
    required this.guestsCount,
    this.zone,
    this.comment,
    required this.status,
  });

  final int id;
  final String guestName;
  final String phone;
  final String date;
  final String time;
  final int guestsCount;
  final String? zone;
  final String? comment;
  final String status;

  factory ApiBooking.fromJson(Map<String, dynamic> json) {
    return ApiBooking(
      id: parseInt(json['id'], field: 'id'),
      guestName: parseString(json['guest_name'] ?? json['guestName'], field: 'guest_name'),
      phone: parseString(json['phone'], field: 'phone'),
      date: parseString(json['date'], field: 'date'),
      time: parseString(json['time'], field: 'time'),
      guestsCount: parseInt(json['guests_count'] ?? json['guestsCount'], field: 'guests_count'),
      zone: parseStringOrNull(json['zone']),
      comment: parseStringOrNull(json['comment']),
      status: parseString(json['status'], field: 'status'),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'guest_name': guestName,
      'phone': phone,
      'date': date,
      'time': time,
      'guests_count': guestsCount,
      'status': status,
    };
    if (zone != null) map['zone'] = zone;
    if (comment != null) map['comment'] = comment;
    return map;
  }
}

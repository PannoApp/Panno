class BookingRequest {
  const BookingRequest({
    required this.guestName,
    required this.phone,
    required this.date,
    required this.time,
    required this.guestsCount,
    this.zone,
    this.comment,
  });

  final String guestName;
  final String phone;
  final String date;
  final String time;
  final int guestsCount;
  final String? zone;
  final String? comment;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'guest_name': guestName,
      'phone': phone,
      'date': date,
      'time': time,
      'guests_count': guestsCount,
    };
    if (zone != null) map['zone'] = zone;
    if (comment != null) map['comment'] = comment;
    return map;
  }
}

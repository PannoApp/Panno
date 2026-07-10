class BookingRequest {
  const BookingRequest({
    required this.guestName,
    required this.phone,
    required this.date,
    required this.time,
    required this.guestsCount,
    this.zone,
    this.remarkedRoomId,
    this.comment,
  });

  final String guestName;
  final String phone;
  final String date;
  final String time;
  final int guestsCount;
  final String? zone;
  // ID реального зала в Remarked (см. BookingZone) — используется backend'ом,
  // чтобы подобрать стол именно в этом зале при создании брони в Remarked.
  final int? remarkedRoomId;
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
    if (remarkedRoomId != null) map['remarked_room_id'] = remarkedRoomId;
    if (comment != null) map['comment'] = comment;
    return map;
  }
}

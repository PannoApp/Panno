import 'json_utils.dart';
import 'api_event.dart';

class ApiEventReservation {
  const ApiEventReservation({
    required this.id,
    required this.eventId,
    required this.eventDetails,
    required this.guestsCount,
    required this.createdAt,
  });

  final int id;
  final int eventId;
  final ApiEvent eventDetails;
  final int guestsCount;
  final DateTime createdAt;

  factory ApiEventReservation.fromJson(Map<String, dynamic> json) {
    return ApiEventReservation(
      id: parseInt(json['id'], field: 'id'),
      eventId: parseInt(json['event'], field: 'event'),
      eventDetails: ApiEvent.fromJson(
        json['event_details'] as Map<String, dynamic>,
      ),
      guestsCount: parseIntOrNull(json['guests_count']) ?? 1,
      createdAt: parseDateTime(json['created_at'], field: 'created_at'),
    );
  }
}

import 'package:dio/dio.dart';

import '../models/api_event_reservation.dart';
import '../services/api_client.dart';

/// Записи пользователя на мероприятия.
class EventReservationRepository {
  EventReservationRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<int> fetchMyReservationsCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/reservations/my/',
    );
    final results = response.data?['results'];
    if (results is List) return results.length;
    return 0;
  }

  Future<List<ApiEventReservation>> fetchMyReservations() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/reservations/my/',
    );
    final results = response.data?['results'];
    if (results is! List) return [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(ApiEventReservation.fromJson)
        .toList();
  }
}

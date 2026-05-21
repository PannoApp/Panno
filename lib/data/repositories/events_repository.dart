import 'package:dio/dio.dart';
import '../events_news_data.dart';
import '../models/api_event.dart';
import '../models/api_event_photo.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class EventsRepository {
  EventsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<List<ApiEvent>> fetchUpcoming({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/upcoming/',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.parse(
      response.data ?? {},
      (json) => ApiEvent.fromJson(json, isPast: false),
    ).results;
  }

  Future<List<ApiEvent>> fetchArchived({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/archived/',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.parse(
      response.data ?? {},
      (json) => ApiEvent.fromJson(json, isPast: true),
    ).results;
  }

  Future<List<PiligrimNewsPost>> fetchNews({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/news/',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.parse(
      response.data ?? {},
      PiligrimNewsPost.fromJson,
    ).results;
  }

  Future<List<ApiEventPhoto>> fetchPhotoReport(int eventId) async {
    final response = await _dio.get<List<dynamic>>(
      '/events/$eventId/photo-report/',
    );
    return (response.data ?? [])
        .map((e) => ApiEventPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createReservation({
    required int eventId,
    required int guestsCount,
    required String idempotencyKey,
  }) async {
    // Получаем Idempotency-Key извне, чтобы он сохранялся при сетевых повторах (retries)
    await _dio.post<Map<String, dynamic>>(
      '/events/reservations/create/',
      data: {
        'event': eventId,
        'guests_count': guestsCount,
      },
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    );
  }
}

import 'dart:io';

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

  // ─── Admin: Events ───────────────────────────────────────────────────────────

  /// Список всех событий без пагинации (pagination_class = None на бэкенде).
  Future<List<ApiEvent>> fetchAdminEvents() async {
    final response = await _dio.get<List<dynamic>>('/events/admin/events/');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => ApiEvent.fromJson(
              json,
              isPast: DateTime.tryParse(json['date_time']?.toString() ?? '')
                      ?.isBefore(DateTime.now()) ==
                  true,
            ))
        .toList();
  }

  Future<void> createEvent(
    Map<String, dynamic> fields, {
    File? image,
  }) async {
    final data = _buildFormData(fields, image: image);
    await _dio.post<void>('/events/admin/events/', data: data);
  }

  /// С image — multipart PATCH; без image — JSON PATCH.
  Future<void> updateEvent(
    int id,
    Map<String, dynamic> fields, {
    File? image,
  }) async {
    if (image != null) {
      final data = _buildFormData(fields, image: image);
      await _dio.patch<void>('/events/admin/events/$id/', data: data);
    } else {
      await _dio.patch<void>(
        '/events/admin/events/$id/',
        data: _prepareFields(fields),
      );
    }
  }

  Future<void> deleteEvent(int id) async {
    await _dio.delete<void>('/events/admin/events/$id/');
  }

  // ─── Admin: News ─────────────────────────────────────────────────────────────

  /// Список всех новостей без пагинации.
  Future<List<PiligrimNewsPost>> fetchAdminNews() async {
    final response = await _dio.get<List<dynamic>>('/events/admin/news/');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PiligrimNewsPost.fromJson)
        .toList();
  }

  Future<void> createNews(
    Map<String, dynamic> fields, {
    File? image,
  }) async {
    final data = _buildFormData(fields, image: image);
    await _dio.post<void>('/events/admin/news/', data: data);
  }

  Future<void> updateNews(
    int id,
    Map<String, dynamic> fields, {
    File? image,
  }) async {
    final data = _buildFormData(fields, image: image);
    await _dio.patch<void>('/events/admin/news/$id/', data: data);
  }

  Future<void> deleteNews(int id) async {
    await _dio.delete<void>('/events/admin/news/$id/');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// DateTime → UTC ISO8601; остальные значения без изменений.
  Map<String, dynamic> _prepareFields(Map<String, dynamic> fields) {
    return {
      for (final e in fields.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toUtc().toIso8601String()
            : e.value,
    };
  }

  FormData _buildFormData(Map<String, dynamic> fields, {File? image}) {
    final formMap = <String, dynamic>{..._prepareFields(fields)};
    if (image != null) {
      formMap['image'] = MultipartFile.fromFileSync(
        image.path,
        filename: image.path.split('/').last,
      );
    }
    return FormData.fromMap(formMap);
  }
}

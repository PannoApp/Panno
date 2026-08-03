import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../events_news_data.dart';
import '../models/api_event.dart';
import '../models/api_event_photo.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class EventsRepository {
  EventsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;
  bool isOfflineMode = false;

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<List<ApiEvent>> fetchUpcoming({int page = 1}) async {
    final isDefaultRequest = page == 1;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/events/upcoming/',
        queryParameters: {'page': page},
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      if (isDefaultRequest) {
        final prefs = await _getPrefs();
        if (prefs != null) {
          await prefs.setString('cache_events_upcoming', jsonEncode(response.data));
        }
      }
      return PaginatedResponse.parse(
        response.data ?? {},
        (json) => ApiEvent.fromJson(json, isPast: false),
      ).results;
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      if (isDefaultRequest || e.type != DioExceptionType.badResponse) {
        final prefs = await _getPrefs();
        final cached = prefs?.getString('cache_events_upcoming');
        if (cached != null) {
          return PaginatedResponse.parse(
            jsonDecode(cached) as Map<String, dynamic>,
            (json) => ApiEvent.fromJson(json, isPast: false),
          ).results;
        }
      }
      rethrow;
    }
  }

  Future<List<ApiEvent>> fetchArchived({int page = 1}) async {
    final isDefaultRequest = page == 1;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/events/archived/',
        queryParameters: {'page': page},
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      if (isDefaultRequest) {
        final prefs = await _getPrefs();
        if (prefs != null) {
          await prefs.setString('cache_events_archived', jsonEncode(response.data));
        }
      }
      return PaginatedResponse.parse(
        response.data ?? {},
        (json) => ApiEvent.fromJson(json, isPast: true),
      ).results;
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      if (isDefaultRequest || e.type != DioExceptionType.badResponse) {
        final prefs = await _getPrefs();
        final cached = prefs?.getString('cache_events_archived');
        if (cached != null) {
          return PaginatedResponse.parse(
            jsonDecode(cached) as Map<String, dynamic>,
            (json) => ApiEvent.fromJson(json, isPast: true),
          ).results;
        }
      }
      rethrow;
    }
  }

  Future<List<PiligrimNewsPost>> fetchNews({int page = 1}) async {
    final isDefaultRequest = page == 1;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/events/news/',
        queryParameters: {'page': page},
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      if (isDefaultRequest) {
        final prefs = await _getPrefs();
        if (prefs != null) {
          await prefs.setString('cache_news', jsonEncode(response.data));
        }
      }
      return PaginatedResponse.parse(
        response.data ?? {},
        PiligrimNewsPost.fromJson,
      ).results;
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      if (isDefaultRequest || e.type != DioExceptionType.badResponse) {
        final prefs = await _getPrefs();
        final cached = prefs?.getString('cache_news');
        if (cached != null) {
          return PaginatedResponse.parse(
            jsonDecode(cached) as Map<String, dynamic>,
            PiligrimNewsPost.fromJson,
          ).results;
        }
      }
      rethrow;
    }
  }

  Future<List<ApiEventPhoto>> fetchPhotoReport(int eventId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/events/$eventId/photo-report/',
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_photo_report_$eventId', jsonEncode(response.data));
      }
      return (response.data ?? [])
          .map((e) => ApiEventPhoto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_photo_report_$eventId');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) => ApiEventPhoto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
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

  Future<ApiEventPhoto> addPhotoToReport(int eventId, File image) async {
    final data = FormData.fromMap({
      'image': MultipartFile.fromFileSync(
        image.path,
        filename: image.path.split('/').last,
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/admin/events/$eventId/photos/',
      data: data,
    );
    return ApiEventPhoto.fromJson(response.data!);
  }

  Future<void> deletePhotoFromReport(int eventId, int photoId) async {
    await _dio.delete<void>('/events/admin/events/$eventId/photos/$photoId/');
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

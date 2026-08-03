// MenuRepository — HTTP-запросы к API меню (/menu/categories/, /menu/tags/, /menu/dishes/)
// Паттерн аналогичен EventsRepository: DioClient.instance.dio по умолчанию.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_allergen.dart';
import '../models/api_category.dart';
import '../models/api_dish.dart';
import '../models/api_tag.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class MenuRepository {
  MenuRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;
  bool isOfflineMode = false;

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  // Загружает список категорий меню. Эндпоинт возвращает плоский массив (без пагинации).
  Future<List<ApiCategory>> fetchCategories() async {
    try {
      final response = await _dio.get<List<dynamic>>('/menu/categories/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_categories', jsonEncode(response.data));
      }
      final list = response.data;
      if (list == null) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ApiCategory.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_categories');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(ApiCategory.fromJson)
            .toList(growable: false);
      }
      return const [];
    }
  }

  // Загружает все теги меню. Эндпоинт возвращает плоский массив (без пагинации).
  Future<List<ApiTag>> fetchTags() async {
    try {
      final response = await _dio.get<List<dynamic>>('/menu/tags/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_tags', jsonEncode(response.data));
      }
      final list = response.data;
      if (list == null) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ApiTag.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_tags');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(ApiTag.fromJson)
            .toList(growable: false);
      }
      return const [];
    }
  }

  Future<List<ApiAllergen>> fetchAllergens() async {
    try {
      final response = await _dio.get<List<dynamic>>('/menu/allergens/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_allergens', jsonEncode(response.data));
      }
      final list = response.data;
      if (list == null) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ApiAllergen.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_allergens');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(ApiAllergen.fromJson)
            .toList(growable: false);
      }
      return const [];
    }
  }

  // Загружает страницу блюд с опциональными фильтрами.
  // Возвращает record: dishes — список блюд, hasMore — есть ли следующая страница.
  Future<({List<ApiDish> dishes, bool hasMore})> fetchDishes({
    int? categoryId,
    List<int>? tagIds,
    String? search,
    int page = 1,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (categoryId != null) query['category_id'] = categoryId;
    if (tagIds != null && tagIds.isNotEmpty) query['tag_ids'] = tagIds.join(',');
    if (search != null && search.isNotEmpty) query['search'] = search;

    final isDefaultRequest = categoryId == null && (tagIds == null || tagIds.isEmpty) && (search == null || search.isEmpty) && page == 1;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/menu/dishes/',
        queryParameters: query,
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      if (isDefaultRequest) {
        final prefs = await _getPrefs();
        if (prefs != null) {
          await prefs.setString('cache_dishes_default', jsonEncode(response.data));
        }
      }
      final paginated = PaginatedResponse.parse(
        response.data ?? {},
        ApiDish.fromJson,
      );
      return (dishes: paginated.results, hasMore: paginated.hasMore);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      if (isDefaultRequest || e.type != DioExceptionType.badResponse) {
        final prefs = await _getPrefs();
        final cached = prefs?.getString('cache_dishes_default');
        if (cached != null) {
          final paginated = PaginatedResponse.parse(
            jsonDecode(cached) as Map<String, dynamic>,
            ApiDish.fromJson,
          );
          return (dishes: paginated.results, hasMore: false);
        }
      }
      rethrow;
    }
  }

  /// Загружает страницу видео-ленты с cursor-based пагинацией.
  /// [cursor] — значение из предыдущего ответа; null означает первую страницу.
  /// Возвращает record: dishes — список блюд, nextCursor — курсор следующей страницы
  /// (null, если страниц больше нет).
  Future<({List<ApiDish> dishes, String? nextCursor})> fetchFeed({
    String? cursor,
  }) async {
    final query = <String, dynamic>{};
    if (cursor != null) query['cursor'] = cursor;

    final isDefaultRequest = cursor == null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/menu/feed/',
        queryParameters: query.isEmpty ? null : query,
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      if (isDefaultRequest) {
        final prefs = await _getPrefs();
        if (prefs != null) {
          await prefs.setString('cache_feed_default', jsonEncode(response.data));
        }
      }
      final paginated = PaginatedResponse.parseCursor(
        response.data ?? {},
        ApiDish.fromJson,
      );
      return (dishes: paginated.results, nextCursor: paginated.nextCursor);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      if (isDefaultRequest || e.type != DioExceptionType.badResponse) {
        final prefs = await _getPrefs();
        final cached = prefs?.getString('cache_feed_default');
        if (cached != null) {
          final paginated = PaginatedResponse.parseCursor(
            jsonDecode(cached) as Map<String, dynamic>,
            ApiDish.fromJson,
          );
          return (dishes: paginated.results, nextCursor: null);
        }
      }
      rethrow;
    }
  }

  /// Загружает полные данные одного блюда по id, включая теги и аллергены.
  Future<ApiDish> fetchDish(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/menu/dishes/$id/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_dish_$id', jsonEncode(response.data));
      }
      return ApiDish.fromJson(response.data!);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_dish_$id');
      if (cached != null) {
        return ApiDish.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  // ── Admin CRUD ─────────────────────────────────────────────────────────────

  /// Все блюда для стафф/администраторов, включая is_active=false.
  /// Обрабатывает как плоский список, так и paginated-ответ.
  Future<List<ApiDish>> fetchAdminDishes({int page = 1}) async {
    final response = await _dio.get<dynamic>(
      '/menu/staff/dishes/',
      queryParameters: {'page': page},
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ApiDish.fromJson)
          .toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      return PaginatedResponse.parse(data, ApiDish.fromJson).results;
    }
    return const [];
  }

  /// Создаёт новое блюдо. Всегда отправляет multipart (image/video опциональны).
  /// Lists (tags, allergens) передаются как JSON-строки: tags_json="[1,2]"
  /// — StaffDishSerializer.validate() разворачивает их на сервере.
  Future<ApiDish> createDish(
    Map<String, dynamic> fields, {
    File? image,
    File? video,
  }) async {
    final data = await _buildFormData(fields, image, video);
    final response = await _dio.post<Map<String, dynamic>>(
      '/menu/staff/dishes/',
      data: data,
    );
    return ApiDish.fromJson(response.data!);
  }

  /// Обновляет блюдо частично (PATCH).
  /// С image или video → multipart/form-data; без обоих → application/json.
  Future<ApiDish> updateDish(
    int id,
    Map<String, dynamic> fields, {
    File? image,
    File? video,
  }) async {
    final Response<Map<String, dynamic>> response;
    if (image != null || video != null) {
      final data = await _buildFormData(fields, image, video);
      response = await _dio.patch<Map<String, dynamic>>(
        '/menu/staff/dishes/$id/',
        data: data,
      );
    } else {
      final jsonFields = _encodeListFields(fields);
      response = await _dio.patch<Map<String, dynamic>>(
        '/menu/staff/dishes/$id/',
        data: jsonFields,
      );
    }
    return ApiDish.fromJson(response.data!);
  }

  /// Удаляет блюдо. Ожидает 204 No Content.
  Future<void> deleteDish(int id) async {
    await _dio.delete<void>('/menu/staff/dishes/$id/');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Собирает FormData: List-поля кодируются как JSON-строки (tags_json, allergens_json),
  /// остальные поля передаются as-is, image и video добавляются как MultipartFile.
  Future<FormData> _buildFormData(
    Map<String, dynamic> fields,
    File? image,
    File? video,
  ) async {
    final map = _encodeListFields(fields);
    if (image != null) {
      map['image'] = await MultipartFile.fromFile(image.path);
    }
    if (video != null) {
      map['video'] = await MultipartFile.fromFile(
        video.path,
        filename: 'dish_video.mp4',
        contentType: MediaType('video', 'mp4'),
      );
    }
    return FormData.fromMap(map);
  }

  /// Возвращает копию fields без изменений.
  /// Списки (tags, allergens) передаются как есть:
  /// — FormData: Dio создаёт повторяющиеся поля (tags=1&tags=2), DRF парсит корректно.
  /// — JSON: Dio сериализует как {"tags": [1, 2]}, DRF тоже понимает.
  Map<String, dynamic> _encodeListFields(Map<String, dynamic> fields) {
    return Map<String, dynamic>.from(fields);
  }
}

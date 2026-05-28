// MenuRepository — HTTP-запросы к API меню (/menu/categories/, /menu/tags/, /menu/dishes/)
// Паттерн аналогичен EventsRepository: DioClient.instance.dio по умолчанию.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/api_allergen.dart';
import '../models/api_category.dart';
import '../models/api_dish.dart';
import '../models/api_tag.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class MenuRepository {
  MenuRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  // Загружает список категорий меню. Эндпоинт возвращает плоский массив (без пагинации).
  Future<List<ApiCategory>> fetchCategories() async {
    final response = await _dio.get<List<dynamic>>('/menu/categories/');
    final list = response.data;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiCategory.fromJson)
        .toList(growable: false);
  }

  // Загружает все теги меню. Эндпоинт возвращает плоский массив (без пагинации).
  Future<List<ApiTag>> fetchTags() async {
    final response = await _dio.get<List<dynamic>>('/menu/tags/');
    final list = response.data;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiTag.fromJson)
        .toList(growable: false);
  }

  Future<List<ApiAllergen>> fetchAllergens() async {
    final response = await _dio.get<List<dynamic>>('/menu/allergens/');
    final list = response.data;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiAllergen.fromJson)
        .toList(growable: false);
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

    final response = await _dio.get<Map<String, dynamic>>(
      '/menu/dishes/',
      queryParameters: query,
    );
    final paginated = PaginatedResponse.parse(
      response.data ?? {},
      ApiDish.fromJson,
    );
    return (dishes: paginated.results, hasMore: paginated.hasMore);
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

    final response = await _dio.get<Map<String, dynamic>>(
      '/menu/feed/',
      queryParameters: query.isEmpty ? null : query,
    );
    final paginated = PaginatedResponse.parseCursor(
      response.data ?? {},
      ApiDish.fromJson,
    );
    return (dishes: paginated.results, nextCursor: paginated.nextCursor);
  }

  // ── Admin CRUD ─────────────────────────────────────────────────────────────

  /// Все блюда для стафф/администраторов, включая is_active=false.
  /// Обрабатывает как плоский список, так и paginated-ответ.
  Future<List<ApiDish>> fetchAdminDishes({int page = 1}) async {
    final response = await _dio.get<dynamic>(
      '/menu/admin/dishes/',
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
      '/menu/admin/dishes/',
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
        '/menu/admin/dishes/$id/',
        data: data,
      );
    } else {
      final jsonFields = _encodeListFields(fields);
      response = await _dio.patch<Map<String, dynamic>>(
        '/menu/admin/dishes/$id/',
        data: jsonFields,
      );
    }
    return ApiDish.fromJson(response.data!);
  }

  /// Удаляет блюдо. Ожидает 204 No Content.
  Future<void> deleteDish(int id) async {
    await _dio.delete<void>('/menu/admin/dishes/$id/');
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

  /// Заменяет List-значения на JSON-строки с суффиксом _json.
  Map<String, dynamic> _encodeListFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      if (entry.value is List) {
        result['${entry.key}_json'] = jsonEncode(entry.value);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}

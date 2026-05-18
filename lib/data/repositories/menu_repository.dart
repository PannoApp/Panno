// MenuRepository — HTTP-запросы к API меню (/menu/categories/, /menu/dishes/)
// Паттерн аналогичен EventsRepository: DioClient.instance.dio по умолчанию.
import 'package:dio/dio.dart';

import '../models/api_category.dart';
import '../models/api_dish.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class MenuRepository {
  MenuRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  // Загружает список категорий меню.
  Future<List<ApiCategory>> fetchCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/menu/categories/');
    return PaginatedResponse.parse(
      response.data ?? {},
      ApiCategory.fromJson,
    ).results;
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
    if (tagIds != null && tagIds.isNotEmpty) query['tags'] = tagIds;
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
}

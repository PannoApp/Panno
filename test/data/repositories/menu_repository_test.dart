import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/repositories/menu_repository.dart';

import '../../support/mock_dio_adapter.dart';

// Тестовый JSON-блюда — структура соответствует реальному ответу DishSerializer.
// category и tags — вложенные объекты, как шлёт бекенд.
Map<String, dynamic> _dishJson({int id = 1, int categoryId = 2}) => {
      'id': id,
      'name': 'Тестовое блюдо $id',
      'description': 'Описание',
      'price': 1500,
      'category': {'id': categoryId, 'name': 'Основной путь', 'order': 0},
      'tags': [
        {'id': 1, 'name': 'Халяль'},
      ],
      'allergens': [
        {'id': 1, 'name': 'глютен'},
      ],
      'image': null,
      'video': null,
      'weight': 200,
      'story': 'История',
      'is_active': true,
    };

// Тестовый JSON-категории — без slug (поля нет в CategorySerializer).
Map<String, dynamic> _categoryJson({int id = 1, String name = 'Основной путь'}) => {
      'id': id,
      'name': name,
      'order': 0,
    };

void main() {
  group('MenuRepository', () {
    late MockDioAdapter adapter;
    late MenuRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = MenuRepository(dio: createMockDio(adapter));
    });

    test('fetchCategories() парсит список ApiCategory', () async {
      adapter.enqueue(200, {
        'results': [_categoryJson(id: 1, name: 'Основной путь')],
        'next': null,
      });

      final categories = await repository.fetchCategories();
      expect(categories, hasLength(1));
      expect(categories.first, isA<ApiCategory>());
      expect(categories.first.id, 1);
      expect(categories.first.name, 'Основной путь');
    });

    test('fetchDishes() без фильтров возвращает первую страницу', () async {
      adapter.enqueue(200, {
        'results': [_dishJson(id: 1), _dishJson(id: 2)],
        'next': 'http://test/api/v1/menu/dishes/?page=2',
      });

      final result = await repository.fetchDishes();
      expect(result.dishes, hasLength(2));
      expect(result.dishes.first, isA<ApiDish>());
      expect(result.hasMore, isTrue);
    });

    test('fetchDishes() корректно парсит вложенные теги и категорию', () async {
      adapter.enqueue(200, {
        'results': [_dishJson(id: 1, categoryId: 3)],
        'next': null,
      });

      final result = await repository.fetchDishes();
      final dish = result.dishes.first;
      expect(dish.category, 3);
      expect(dish.tags, hasLength(1));
      expect(dish.tags.first.name, 'Халяль');
      expect(dish.allergens.first, 'глютен');
    });

    test('fetchDishes(categoryId: 2) добавляет query param category_id=2',
        () async {
      adapter.enqueue(200, {
        'results': [_dishJson(id: 3, categoryId: 2)],
        'next': null,
      });

      await repository.fetchDishes(categoryId: 2);

      final req = adapter.captured.single;
      expect(req.queryParameters['category_id'], 2);
    });

    test('fetchDishes() устанавливает hasMore=false когда next == null',
        () async {
      adapter.enqueue(200, {
        'results': [_dishJson()],
        'next': null,
      });

      final result = await repository.fetchDishes();
      expect(result.hasMore, isFalse);
    });

    test('fetchDishes(search: «стейк») добавляет query param search', () async {
      adapter.enqueue(200, {'results': [], 'next': null});

      await repository.fetchDishes(search: 'стейк');

      final req = adapter.captured.single;
      expect(req.queryParameters['search'], 'стейк');
    });

    test('fetchDishes() выбрасывает DioException при ответе 500', () async {
      adapter.enqueue(500, {'detail': 'error'});
      expect(repository.fetchDishes(), throwsA(isA<DioException>()));
    });
  });
}

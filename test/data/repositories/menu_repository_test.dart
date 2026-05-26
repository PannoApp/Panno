import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_allergen.dart';
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
      adapter.enqueue(200, [
        _categoryJson(id: 1, name: 'Основной путь'),
      ]);

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

    test('fetchAllergens() парсит список ApiAllergen', () async {
      adapter.enqueue(200, [
        {'id': 1, 'name': 'глютен'},
        {'id': 2, 'name': 'лактоза'},
      ]);

      final allergens = await repository.fetchAllergens();
      expect(allergens, hasLength(2));
      expect(allergens.first, isA<ApiAllergen>());
      expect(allergens.first.id, 1);
      expect(allergens.first.name, 'глютен');
      expect(allergens.last.name, 'лактоза');
    });

    test('fetchAllergens() возвращает пустой список при ответе []', () async {
      adapter.enqueue(200, <dynamic>[]);

      final allergens = await repository.fetchAllergens();
      expect(allergens, isEmpty);
    });

    // ── Admin CRUD ────────────────────────────────────────────────────────────

    test('fetchAdminDishes() парсит paginated-ответ включая is_active=false',
        () async {
      adapter.enqueue(200, {
        'results': [
          _dishJson(id: 1)..['is_active'] = false,
          _dishJson(id: 2),
        ],
        'next': null,
      });

      final dishes = await repository.fetchAdminDishes();
      expect(dishes, hasLength(2));
      expect(dishes.first, isA<ApiDish>());
    });

    test('fetchAdminDishes() обрабатывает плоский список', () async {
      adapter.enqueue(200, [_dishJson(id: 5), _dishJson(id: 6)]);

      final dishes = await repository.fetchAdminDishes();
      expect(dishes, hasLength(2));
      expect(dishes.first.id, 5);
    });

    test('createDish() отправляет POST на /menu/admin/dishes/ и возвращает ApiDish',
        () async {
      adapter.enqueue(201, _dishJson(id: 99));

      final dish = await repository.createDish({
        'name': 'Новое блюдо',
        'price': 2000,
        'tags': [1, 2],
      });

      expect(dish, isA<ApiDish>());
      expect(dish.id, 99);
      final req = adapter.captured.single;
      expect(req.path, contains('/menu/admin/dishes/'));
      expect(req.method, 'POST');
    });

    test('updateDish() без image отправляет PATCH JSON с _json-полями для списков',
        () async {
      adapter.enqueue(200, _dishJson(id: 7));

      final dish = await repository.updateDish(7, {
        'name': 'Обновлённое',
        'tags': [3],
        'allergens': [1, 2],
      });

      expect(dish.id, 7);
      final req = adapter.captured.single;
      expect(req.method, 'PATCH');
      expect(req.path, contains('/menu/admin/dishes/7/'));
      final body = req.data as Map<String, dynamic>;
      expect(body['tags_json'], '[3]');
      expect(body['allergens_json'], '[1,2]');
      expect(body['name'], 'Обновлённое');
    });

    test('deleteDish() отправляет DELETE на /menu/admin/dishes/id/', () async {
      adapter.enqueue(204, null);

      await repository.deleteDish(42);

      final req = adapter.captured.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/menu/admin/dishes/42/'));
    });

    // ── Расширенные admin-тесты ───────────────────────────────────────────────

    // test_fetchAdminDishes_returns_all
    test(
        'fetchAdminDishes() сохраняет isActive=false и возвращает весь список',
        () async {
      adapter.enqueue(200, {
        'results': [
          {..._dishJson(id: 1), 'is_active': false},
          {..._dishJson(id: 2), 'is_active': true},
        ],
        'next': null,
      });

      final dishes = await repository.fetchAdminDishes();

      expect(dishes, hasLength(2));
      expect(dishes[0].isActive, isFalse);
      expect(dishes[1].isActive, isTrue);
    });

    // test_createDish_sends_multipart
    test('createDish() отправляет FormData с полями и закодированными списками',
        () async {
      adapter.enqueue(201, _dishJson(id: 10));

      await repository.createDish({
        'name': 'Блюдо',
        'price': 1000,
        'tags': [1, 3],
        'allergens': [2],
      });

      final req = adapter.captured.single;
      expect(req.data, isA<FormData>());
      final fd = req.data as FormData;
      expect(fd.fields.any((e) => e.key == 'name' && e.value == 'Блюдо'), isTrue);
      expect(fd.fields.any((e) => e.key == 'price' && e.value == '1000'), isTrue);
      expect(fd.fields.any((e) => e.key == 'tags_json' && e.value == '[1,3]'), isTrue);
      expect(fd.fields.any((e) => e.key == 'allergens_json' && e.value == '[2]'), isTrue);
    });

    // test_updateDish_with_image_sends_multipart
    test('updateDish() с image отправляет FormData с MultipartFile', () async {
      adapter.enqueue(200, _dishJson(id: 3));

      final tmpFile = File('${Directory.systemTemp.path}/test_dish_upload.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      try {
        await repository.updateDish(3, {'name': 'С фото'}, image: tmpFile);

        final req = adapter.captured.single;
        expect(req.method, 'PATCH');
        expect(req.path, contains('/menu/admin/dishes/3/'));
        expect(req.data, isA<FormData>());
        final fd = req.data as FormData;
        expect(fd.files.any((e) => e.key == 'image'), isTrue);
        expect(fd.fields.any((e) => e.key == 'name' && e.value == 'С фото'), isTrue);
      } finally {
        tmpFile.deleteSync();
      }
    });

    // test_updateDish_without_image_sends_json
    test('updateDish() без image отправляет Map (не FormData)', () async {
      adapter.enqueue(200, _dishJson(id: 4));

      await repository.updateDish(4, {'price': 500});

      final req = adapter.captured.single;
      expect(req.data, isNot(isA<FormData>()));
      expect(req.data, isA<Map<String, dynamic>>());
      expect((req.data as Map<String, dynamic>)['price'], 500);
    });

    // test_deleteDish_calls_delete
    test('deleteDish() вызывает DELETE точно на /menu/admin/dishes/7/', () async {
      adapter.enqueue(204, null);

      await repository.deleteDish(7);

      final req = adapter.captured.single;
      expect(req.method, 'DELETE');
      expect(req.path, endsWith('/menu/admin/dishes/7/'));
    });
  });
}

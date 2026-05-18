import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/models/api_tag.dart';
import 'package:piligrim/data/repositories/menu_repository.dart';
import 'package:piligrim/providers/menu_provider.dart';

class _MockMenuRepository extends Mock implements MenuRepository {}

// Вспомогательное блюдо для тестов
ApiDish _sampleDish({int id = 1}) => ApiDish(
      id: id,
      name: 'Блюдо $id',
      description: 'Описание',
      price: 1000,
      category: 1,
      tags: const <ApiTag>[],
      allergens: const [],
      weight: '200 г',
      story: 'История',
      isActive: true,
    );

// Пагинированный ответ-заглушка
({List<ApiDish> dishes, bool hasMore}) _page(
  List<ApiDish> dishes, {
  bool hasMore = false,
}) =>
    (dishes: dishes, hasMore: hasMore);

void main() {
  group('MenuProvider', () {
    late _MockMenuRepository repository;

    setUp(() {
      repository = _MockMenuRepository();
      // fetchCategories() по умолчанию возвращает пустой список
      when(() => repository.fetchCategories())
          .thenAnswer((_) async => const <ApiCategory>[]);
    });

    test('loadDishes() на пустом state: isLoading=true → false, dishes добавлены',
        () async {
      when(() => repository.fetchDishes(page: 1))
          .thenAnswer((_) async => _page([_sampleDish()]));

      final provider = MenuProvider(repository: repository);

      // Начинаем загрузку и проверяем что isLoading=true в процессе
      var loadingObserved = false;
      provider.addListener(() {
        if (provider.isLoading) loadingObserved = true;
      });

      await provider.loadDishes(refresh: true);

      expect(loadingObserved, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.dishes, hasLength(1));
    });

    test('loadDishes() добавляет dishes к существующему списку (пагинация)',
        () async {
      // Страница 1 с hasMore=true, страница 2 с hasMore=false
      when(() => repository.fetchDishes(page: 1))
          .thenAnswer((_) async => _page([_sampleDish(id: 1)], hasMore: true));
      when(() => repository.fetchDishes(page: 2))
          .thenAnswer((_) async => _page([_sampleDish(id: 2)]));

      final provider = MenuProvider(repository: repository);
      await provider.loadDishes(refresh: true);
      expect(provider.dishes, hasLength(1));
      expect(provider.hasMore, isTrue);

      await provider.loadDishes();
      expect(provider.dishes, hasLength(2));
      expect(provider.hasMore, isFalse);
    });

    test('loadDishes() с hasMore=false не делает повторный запрос', () async {
      when(() => repository.fetchDishes(page: 1))
          .thenAnswer((_) async => _page([_sampleDish()]));

      final provider = MenuProvider(repository: repository);
      await provider.loadDishes(refresh: true);
      expect(provider.hasMore, isFalse);

      // Повторный вызов без refresh не должен обращаться к репозиторию
      await provider.loadDishes();

      verify(() => repository.fetchDishes(page: 1)).called(1);
      verifyNever(() => repository.fetchDishes(page: 2));
    });

    test('setCategory() сбрасывает список и вызывает loadDishes заново',
        () async {
      when(() => repository.fetchDishes(page: 1))
          .thenAnswer((_) async => _page([_sampleDish(id: 1)]));
      when(() => repository.fetchDishes(categoryId: 5, page: 1))
          .thenAnswer((_) async => _page([_sampleDish(id: 2)]));

      final provider = MenuProvider(repository: repository);
      await provider.loadDishes(refresh: true);
      expect(provider.dishes, hasLength(1));

      // setCategory вызывает loadDishes(refresh: true) внутри
      provider.setCategory(5);
      await Future<void>.delayed(Duration.zero);

      expect(provider.activeCategoryId, 5);
      expect(provider.dishes, hasLength(1));
      expect(provider.dishes.first.id, 2);
    });

    test('setSearch() с debounce 400мс вызывает loadDishes единожды', () async {
      when(() => repository.fetchDishes(search: 'чай', page: 1))
          .thenAnswer((_) async => _page([_sampleDish()]));
      when(() => repository.fetchDishes(search: 'кок-чай', page: 1))
          .thenAnswer((_) async => _page([_sampleDish(id: 2)]));

      final provider = MenuProvider(repository: repository);

      // Быстрый ввод: несколько вызовов подряд
      provider.setSearch('ч');
      provider.setSearch('ча');
      provider.setSearch('чай');

      // До истечения debounce запросов нет
      verifyNever(() => repository.fetchDishes(
          search: any(named: 'search'), page: any(named: 'page')));

      // Ждём debounce
      await Future<void>.delayed(const Duration(milliseconds: 450));

      // Должен был выполниться ровно один запрос с последним значением
      verify(() => repository.fetchDishes(search: 'чай', page: 1)).called(1);
    });
  });
}

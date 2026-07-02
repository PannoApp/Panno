import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piligrim/core/dio_errors.dart';
import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/models/api_tag.dart';
import 'package:piligrim/data/repositories/menu_repository.dart';
import 'package:piligrim/providers/menu_provider.dart';

class _MockMenuRepository extends Mock implements MenuRepository {}

DioException _timeoutException() => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionTimeout,
    );

DioException _badResponseException(int status) => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: status,
      ),
    );

ApiDish _dish({int id = 1}) => ApiDish(
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

void main() {
  group('dioErrorMessage()', () {
    test('DioException connectionTimeout → "Нет соединения"', () {
      expect(dioErrorMessage(_timeoutException()), 'Нет соединения');
    });

    test('DioException 503 → "Сервер временно недоступен"', () {
      expect(
        dioErrorMessage(_badResponseException(503)),
        'Сервер временно недоступен',
      );
    });
  });

  group('MenuProvider — обработка ошибок', () {
    late _MockMenuRepository repo;

    setUp(() {
      repo = _MockMenuRepository();
      when(() => repo.fetchCategories()).thenAnswer((_) async => const <ApiCategory>[]);
      when(() => repo.fetchFeed(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => (dishes: const <ApiDish>[], nextCursor: null));
    });

    test('retry() сбрасывает error и повторяет запрос', () async {
      SharedPreferences.setMockInitialValues({});

      // Первый запрос бросает ошибку
      when(() => repo.fetchDishes(page: 1)).thenThrow(_timeoutException());

      final provider = MenuProvider(repository: repo);
      await provider.loadDishes(refresh: true);

      expect(provider.error, 'Нет соединения');

      // Второй запрос (после retry) успешен
      when(() => repo.fetchDishes(page: 1))
          .thenAnswer((_) async => (dishes: [_dish()], hasMore: false));

      await provider.retry();

      expect(provider.error, isNull);
      expect(provider.dishes, hasLength(1));
    });

    test('MenuProvider: при ошибке сохраняет stale данные', () async {
      // Первая страница загружается успешно
      when(() => repo.fetchDishes(page: 1))
          .thenAnswer((_) async => (dishes: [_dish(id: 1)], hasMore: true));

      final provider = MenuProvider(repository: repo);
      await provider.loadDishes(refresh: true);

      expect(provider.dishes, hasLength(1));
      expect(provider.hasMore, isTrue);

      // Вторая страница бросает ошибку — первая страница остаётся в provider
      when(() => repo.fetchDishes(page: 2)).thenThrow(_badResponseException(503));

      await provider.loadDishes(); // не refresh → stale данные не сбрасываются

      expect(provider.error, 'Сервер временно недоступен');
      expect(provider.dishes, hasLength(1));
      expect(provider.dishes.first.id, 1);
    });
  });
}

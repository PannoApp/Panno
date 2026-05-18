import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/models/api_tag.dart';

void main() {
  group('ApiDish.fromJson', () {
    // Полный JSON в формате DishSerializer (вложенные объекты)
    test('parses all fields', () {
      final dish = ApiDish.fromJson({
        'id': 1,
        'name': 'Бешбармак',
        'description': 'Традиционное блюдо',
        'price': 4500,
        'category': {'id': 2, 'name': 'Горячее', 'order': 1},
        'tags': [
          {'id': 10, 'name': 'Халяль'},
          {'id': 11, 'name': 'Авторское'},
        ],
        'allergens': [
          {'id': 1, 'name': 'глютен'},
        ],
        'image': 'https://cdn.example/dish.jpg',
        'video': 'https://cdn.example/dish.mp4',
        'weight': 350,
        'story': 'История блюда',
        'is_active': true,
      });

      expect(dish.id, 1);
      expect(dish.name, 'Бешбармак');
      expect(dish.description, 'Традиционное блюдо');
      expect(dish.price, 4500);
      // category — id из вложенного объекта
      expect(dish.category, 2);
      // tags — список ApiTag
      expect(dish.tags, hasLength(2));
      expect(dish.tags.first, isA<ApiTag>());
      expect(dish.tags.first.id, 10);
      expect(dish.tags.first.name, 'Халяль');
      // allergens — имена из вложенных объектов
      expect(dish.allergens, ['глютен']);
      expect(dish.imageUrl, 'https://cdn.example/dish.jpg');
      expect(dish.videoUrl, 'https://cdn.example/dish.mp4');
      expect(dish.weight, '350');
      expect(dish.story, 'История блюда');
      expect(dish.isActive, true);
    });

    test('allows null image and video', () {
      final dish = ApiDish.fromJson({
        'id': 2,
        'name': 'Чай',
        'description': '',
        'price': '900',
        'category': {'id': 1, 'name': 'Напитки', 'order': 5},
        'tags': [],
        'allergens': [],
        'image': null,
        'video': null,
        'weight': 300,
        'story': '',
        'is_active': false,
      });

      expect(dish.imageUrl, isNull);
      expect(dish.videoUrl, isNull);
      expect(dish.price, 900);
      expect(dish.tags, isEmpty);
    });

    test('converts price from string to int', () {
      final dish = ApiDish.fromJson({
        'id': 3,
        'name': 'Суп',
        'description': 'd',
        'price': '12500',
        'category': 1,
        'tags': [],
        'allergens': [],
        'weight': 250,
        'story': 's',
        'is_active': true,
      });

      expect(dish.price, 12500);
    });
  });
}

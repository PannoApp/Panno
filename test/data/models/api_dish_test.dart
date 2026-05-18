import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_dish.dart';

void main() {
  group('ApiDish.fromJson', () {
    test('parses all fields', () {
      final dish = ApiDish.fromJson({
        'id': 1,
        'name': 'Бешбармак',
        'description': 'Традиционное блюдо',
        'price': 4500,
        'category': 2,
        'tags': ['традиция', 'мясо'],
        'allergens': ['глютен'],
        'image_url': 'https://cdn.example/dish.jpg',
        'video_url': 'https://cdn.example/dish.mp4',
        'weight': '350 г',
        'story': 'История блюда',
        'is_active': true,
      });

      expect(dish.id, 1);
      expect(dish.name, 'Бешбармак');
      expect(dish.description, 'Традиционное блюдо');
      expect(dish.price, 4500);
      expect(dish.category, 2);
      expect(dish.tags, ['традиция', 'мясо']);
      expect(dish.allergens, ['глютен']);
      expect(dish.imageUrl, 'https://cdn.example/dish.jpg');
      expect(dish.videoUrl, 'https://cdn.example/dish.mp4');
      expect(dish.weight, '350 г');
      expect(dish.story, 'История блюда');
      expect(dish.isActive, true);
    });

    test('allows null imageUrl and videoUrl', () {
      final dish = ApiDish.fromJson({
        'id': 2,
        'name': 'Чай',
        'description': '',
        'price': '900',
        'category': 1,
        'tags': [],
        'allergens': [],
        'image_url': null,
        'video_url': null,
        'weight': '300 мл',
        'story': '',
        'is_active': false,
      });

      expect(dish.imageUrl, isNull);
      expect(dish.videoUrl, isNull);
      expect(dish.price, 900);
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
        'weight': '250 г',
        'story': 's',
        'is_active': true,
      });

      expect(dish.price, 12500);
    });
  });
}

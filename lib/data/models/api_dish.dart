import 'api_tag.dart';
import 'json_utils.dart';

// Извлекает id из вложенного объекта категории или напрямую из int.
// DishSerializer возвращает category как {"id": 1, "name": "...", "order": 0}.
int _parseCategoryId(dynamic value) {
  if (value is Map) return parseInt(value['id'], field: 'category.id');
  return parseInt(value, field: 'category');
}

// Парсит аллергены из списка объектов [{"id":1,"name":"глютен"},...] или строк.
List<String> _parseAllergens(dynamic value) {
  if (value == null || value is! List) return const [];
  return value.map<String>((e) {
    if (e is Map) return asJsonMap(e)['name']?.toString() ?? '';
    return e.toString();
  }).where((s) => s.isNotEmpty).toList(growable: false);
}

class ApiDish {
  const ApiDish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.tags,
    required this.allergens,
    this.imageUrl,
    this.videoUrl,
    required this.weight,
    required this.story,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final int price;
  final int category;
  final List<ApiTag> tags;
  final List<String> allergens;
  final String? imageUrl;
  final String? videoUrl;
  final String weight;
  final String story;
  final bool isActive;

  factory ApiDish.fromJson(Map<String, dynamic> json) {
    return ApiDish(
      id: parseInt(json['id'], field: 'id'),
      name: parseString(json['name'], field: 'name'),
      description: parseString(json['description'], field: 'description'),
      price: parseInt(json['price'], field: 'price'),
      // category — вложенный объект с сервера: {"id": 1, "name": "...", "order": 0}
      category: _parseCategoryId(json['category']),
      // tags — список объектов: [{"id": 1, "name": "Халяль"}, ...]
      tags: asJsonMapList(json['tags']).map(ApiTag.fromJson).toList(growable: false),
      // allergens — тоже список объектов: [{"id": 1, "name": "глютен"}, ...]
      allergens: _parseAllergens(json['allergens']),
      // backend поле называется 'image' (не image_url)
      imageUrl: parseStringOrNull(json['image']),
      // backend поле называется 'video' (не video_url)
      videoUrl: parseStringOrNull(json['video']),
      weight: parseString(json['weight'] ?? '', field: 'weight'),
      story: parseString(json['story'] ?? '', field: 'story'),
      isActive: parseBool(json['is_active'] ?? json['isActive'], defaultValue: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'tags': tags.map((t) => t.toJson()).toList(),
        'allergens': allergens,
        if (imageUrl != null) 'image': imageUrl,
        if (videoUrl != null) 'video': videoUrl,
        'weight': weight,
        'story': story,
        'is_active': isActive,
      };
}

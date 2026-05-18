import 'json_utils.dart';

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
  final List<String> tags;
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
      category: parseInt(json['category'], field: 'category'),
      tags: parseStringList(json['tags']),
      allergens: parseStringList(json['allergens']),
      imageUrl: parseStringOrNull(json['image_url'] ?? json['imageUrl']),
      videoUrl: parseStringOrNull(json['video_url'] ?? json['videoUrl']),
      weight: parseString(json['weight'], field: 'weight'),
      story: parseString(json['story'], field: 'story'),
      isActive: parseBool(json['is_active'] ?? json['isActive'], defaultValue: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'tags': tags,
        'allergens': allergens,
        if (imageUrl != null) 'image_url': imageUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        'weight': weight,
        'story': story,
        'is_active': isActive,
      };
}

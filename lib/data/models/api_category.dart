import 'json_utils.dart';

class ApiCategory {
  const ApiCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  factory ApiCategory.fromJson(Map<String, dynamic> json) {
    return ApiCategory(
      id: parseInt(json['id'], field: 'id'),
      name: parseString(json['name'], field: 'name'),
      slug: parseString(json['slug'], field: 'slug'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
      };
}

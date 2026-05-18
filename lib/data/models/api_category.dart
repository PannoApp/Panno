import 'json_utils.dart';

// Категория меню. Backend поля: id, name, order (slug отсутствует).
class ApiCategory {
  const ApiCategory({
    required this.id,
    required this.name,
    required this.order,
  });

  final int id;
  final String name;
  final int order;

  factory ApiCategory.fromJson(Map<String, dynamic> json) {
    return ApiCategory(
      id: parseInt(json['id'], field: 'id'),
      name: parseString(json['name'], field: 'name'),
      order: parseIntOrNull(json['order']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
      };
}

import 'json_utils.dart';

// Тег блюда — приходит с сервера, не хардкодится на клиенте.
// Стиль (иконка, цвет) задаётся в menu_data.dart по имени тега.
class ApiTag {
  const ApiTag({required this.id, required this.name});

  final int id;
  final String name;

  factory ApiTag.fromJson(Map<String, dynamic> json) => ApiTag(
        id: parseInt(json['id'], field: 'id'),
        name: parseString(json['name'], field: 'name'),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is ApiTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

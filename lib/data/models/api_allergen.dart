import 'json_utils.dart';

class ApiAllergen {
  const ApiAllergen({required this.id, required this.name});

  final int id;
  final String name;

  factory ApiAllergen.fromJson(Map<String, dynamic> json) => ApiAllergen(
        id: parseInt(json['id'], field: 'id'),
        name: parseString(json['name'], field: 'name'),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is ApiAllergen && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

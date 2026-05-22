import 'json_utils.dart';
import '../../core/media_url.dart';

class ApiEventPhoto {
  const ApiEventPhoto({
    required this.id,
    required this.imageUrl,
    required this.order,
  });

  final int id;
  final String imageUrl;
  final int order;

  factory ApiEventPhoto.fromJson(Map<String, dynamic> json) => ApiEventPhoto(
        id: parseInt(json['id'], field: 'id'),
        imageUrl: resolveMediaUrl(parseString(json['image'], field: 'image')),
        order: json['order'] as int? ?? 0,
      );
}

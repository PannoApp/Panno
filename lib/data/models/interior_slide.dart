import 'json_utils.dart';
import '../../core/media_url.dart';

class InteriorSlide {
  const InteriorSlide({
    required this.id,
    required this.zone,
    required this.zoneDisplay,
    required this.imageUrl,
    this.caption,
    required this.order,
  });

  final int id;
  final String zone;
  final String zoneDisplay;
  final String imageUrl;
  final String? caption;
  final int order;

  factory InteriorSlide.fromJson(Map<String, dynamic> json) {
    return InteriorSlide(
      id: parseInt(json['id'], field: 'id'),
      zone: parseString(json['zone'], field: 'zone'),
      zoneDisplay: parseString(
        json['zone_display'] ?? json['zoneDisplay'],
        field: 'zone_display',
      ),
      imageUrl: _parseImageUrl(json),
      caption: parseStringOrNull(json['caption']),
      order: parseInt(json['order'], field: 'order'),
    );
  }

  /// Слайд главного экрана: `GET /core/info/` → `hero_slides[]`.
  factory InteriorSlide.fromHeroJson(Map<String, dynamic> json) {
    return InteriorSlide(
      id: parseInt(json['id'], field: 'id'),
      zone: '',
      zoneDisplay: '',
      imageUrl: _parseImageUrl(json),
      order: parseInt(json['order'], field: 'order'),
    );
  }

  static String _parseImageUrl(Map<String, dynamic> json) {
    return resolveMediaUrl(
      parseString(
        json['image_url'] ?? json['imageUrl'] ?? json['image'],
        field: 'image',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'zone': zone,
      'zone_display': zoneDisplay,
      'image_url': imageUrl,
      'order': order,
    };
    if (caption != null) map['caption'] = caption;
    return map;
  }
}

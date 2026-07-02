import 'json_utils.dart';

enum ApiEventFormat { open, closed }

int? _parseDecimalPrice(dynamic v) {
  if (v == null) return null;
  return (double.tryParse('$v') ?? 0.0).round();
}

ApiEventFormat _parseFormat(dynamic value) {
  final raw = parseString(value, field: 'format').toLowerCase();
  switch (raw) {
    case 'open':
      return ApiEventFormat.open;
    case 'closed':
      return ApiEventFormat.closed;
    default:
      throw FormatException('Unknown event format: $raw');
  }
}

class ApiEvent {
  const ApiEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.format,
    this.coverUrl,
    this.priceFrom,
    required this.isPast,
    this.isActive = true,
    this.hasPhotoReport = false,
    this.maxPlaces = 0,
    this.occupiedPlaces = 0,
  });

  final int id;
  final String title;
  final String description;
  final DateTime startsAt;
  final ApiEventFormat format;
  final String? coverUrl;
  final int? priceFrom;
  final bool isPast;
  final bool isActive;
  final bool hasPhotoReport;
  final int maxPlaces;
  final int occupiedPlaces;

  factory ApiEvent.fromJson(
    Map<String, dynamic> json, {
    bool isPast = false,
  }) {
    return ApiEvent(
      id: parseInt(json['id'], field: 'id'),
      title: parseString(json['title'], field: 'title'),
      description: parseString(json['description'], field: 'description'),
      startsAt: parseDateTime(
        json['starts_at'] ?? json['startsAt'] ?? json['date_time'],
        field: 'starts_at',
      ),
      format: _parseFormat(json['format']),
      coverUrl: parseStringOrNull(
        json['cover_url'] ?? json['coverUrl'] ?? json['image'],
      ),
      priceFrom: _parseDecimalPrice(json['price'] ?? json['price_from']),
      isPast: parseBool(json['is_past'] ?? json['isPast'], defaultValue: isPast),
      isActive: parseBool(json['is_active'] ?? json['isActive'], defaultValue: true),
      hasPhotoReport: parseBool(
        json['has_photo_report'] ?? json['hasPhotoReport'],
        defaultValue: false,
      ),
      maxPlaces: parseIntOrNull(json['max_places'] ?? json['maxPlaces']) ?? 0,
      occupiedPlaces: parseIntOrNull(json['occupied_places'] ?? json['occupiedPlaces']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'starts_at': startsAt.toIso8601String(),
        'format': format.name,
        if (coverUrl != null) 'cover_url': coverUrl,
        if (priceFrom != null) 'price_from': priceFrom,
        'is_past': isPast,
        'is_active': isActive,
        'has_photo_report': hasPhotoReport,
        'max_places': maxPlaces,
        'occupied_places': occupiedPlaces,
      };
}

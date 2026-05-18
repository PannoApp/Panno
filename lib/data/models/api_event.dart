import 'json_utils.dart';

enum ApiEventFormat { open, closed }

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
  });

  final int id;
  final String title;
  final String description;
  final DateTime startsAt;
  final ApiEventFormat format;
  final String? coverUrl;
  final int? priceFrom;
  final bool isPast;

  factory ApiEvent.fromJson(Map<String, dynamic> json) {
    return ApiEvent(
      id: parseInt(json['id'], field: 'id'),
      title: parseString(json['title'], field: 'title'),
      description: parseString(json['description'], field: 'description'),
      startsAt: parseDateTime(
        json['starts_at'] ?? json['startsAt'],
        field: 'starts_at',
      ),
      format: _parseFormat(json['format']),
      coverUrl: parseStringOrNull(json['cover_url'] ?? json['coverUrl']),
      priceFrom: parseIntOrNull(json['price_from'] ?? json['priceFrom']),
      isPast: parseBool(json['is_past'] ?? json['isPast']),
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
      };
}

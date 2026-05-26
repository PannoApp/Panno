// Модели и утилиты афиши/новостей
import 'package:flutter/foundation.dart';

import '../core/media_url.dart';
import 'models/json_utils.dart';

@immutable
class PiligrimNewsPost {
  const PiligrimNewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final String? imageUrl;

  // Нужен для admin CRUD (deleteNews / updateNews принимают int id)
  int get numericId => int.tryParse(id) ?? 0;

  factory PiligrimNewsPost.fromJson(Map<String, dynamic> json) {
    return PiligrimNewsPost(
      id: parseInt(json['id'], field: 'id').toString(),
      title: parseString(json['title'], field: 'title'),
      body: parseString(json['content'] ?? json['body'], field: 'content'),
      publishedAt: parseDateTime(
        json['created_at'] ?? json['publishedAt'],
        field: 'created_at',
      ),
      imageUrl: resolveMediaUrl(parseStringOrNull(json['image'] ?? json['image_url'])),
    );
  }
}

const _monthsRu = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

String formatDateTimeRu(DateTime dt) {
  final m = _monthsRu[dt.month - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} $m ${dt.year}, $hh:$mm';
}

String formatShortDateRu(DateTime dt) {
  final m = _monthsRu[dt.month - 1];
  return '${dt.day} $m ${dt.year}';
}

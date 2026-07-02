import '../data/services/api_client.dart';

/// Приводит URL медиафайла к абсолютному виду.
///
/// Если бэкенд вернул относительный путь (`/media/...`), дополняет его
/// origin-ом из [DioClient.mediaOrigin]. Абсолютные URL возвращаются без изменений.
/// Пустая строка / null возвращает пустую строку.
String resolveMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  const origin = DioClient.mediaOrigin;
  return raw.startsWith('/') ? '$origin$raw' : '$origin/$raw';
}

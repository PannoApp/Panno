import 'models/json_utils.dart';

/// DRF-пагинация: `{ count, next, previous, results }`.
/// Поддерживает как page-based, так и cursor-based пагинацию.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.results,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> results;
  final bool hasMore;

  /// Курсор следующей страницы (только для cursor pagination).
  /// Извлекается из query-параметра `cursor` поля `next`.
  final String? nextCursor;

  // Стандартный парсер для page-based пагинации (/menu/dishes/, /events/ и т.д.)
  static PaginatedResponse<T> parse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = json['results'];
    final list = raw is List
        ? raw
            .map((e) => fromJson(asJsonMap(e)))
            .toList(growable: false)
        : <T>[];
    final next = json['next'];
    return PaginatedResponse(
      results: list,
      hasMore: next != null && next.toString().isNotEmpty,
    );
  }

  /// Парсер для cursor-based пагинации (/menu/feed/).
  /// DRF возвращает `next` как полный URL, например:
  ///   https://host/api/v1/menu/feed/?cursor=cD0xNg%3D%3D
  /// Из него извлекается значение параметра `cursor`.
  static PaginatedResponse<T> parseCursor<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = json['results'];
    final list = raw is List
        ? raw
            .map((e) => fromJson(asJsonMap(e)))
            .toList(growable: false)
        : <T>[];
    final nextUrl = json['next'] as String?;
    final cursor = _extractCursor(nextUrl);
    return PaginatedResponse(
      results: list,
      hasMore: cursor != null,
      nextCursor: cursor,
    );
  }

  /// Извлекает значение query-параметра `cursor` из полного URL.
  static String? _extractCursor(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['cursor'];
  }
}

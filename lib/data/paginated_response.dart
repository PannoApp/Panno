import 'models/json_utils.dart';

/// DRF-пагинация: `{ count, next, previous, results }`.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.results,
    required this.hasMore,
  });

  final List<T> results;
  final bool hasMore;

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
}

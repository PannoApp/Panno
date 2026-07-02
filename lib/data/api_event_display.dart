import '../core/interior_assets.dart';
import 'events_news_data.dart';
import 'models/api_event.dart';

extension ApiEventDisplay on ApiEvent {
  String get formatLabelRu => switch (format) {
        ApiEventFormat.open => 'Открытое',
        ApiEventFormat.closed => 'Закрытое',
      };

  String fallbackCoverAsset(int index) {
    final images = PiligrimInteriorAssets.allInteriorPngs;
    if (images.isEmpty) return '';
    return images[index % images.length];
  }
}

/// Fallback: моковые события → [ApiEvent] для офлайн-режима.
List<ApiEvent> mockEventsAsApi() {
  return buildMockEvents().map((e) {
    final id = int.tryParse(e.id) ?? 0;
    return ApiEvent(
      id: id,
      title: e.title,
      description: e.description,
      startsAt: e.startsAt,
      format: e.format == EventAccessFormat.open
          ? ApiEventFormat.open
          : ApiEventFormat.closed,
      coverUrl: null,
      priceFrom: e.priceFromRub,
      isPast: e.isPast,
      hasPhotoReport: e.hasPhotoReport,
    );
  }).toList(growable: false);
}

List<ApiEvent> upcomingApiSorted(List<ApiEvent> events) {
  final list = events.where((e) => !e.isPast).toList();
  list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return list;
}

List<ApiEvent> pastApiSorted(List<ApiEvent> events) {
  final list = events.where((e) => e.isPast).toList();
  list.sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return list;
}

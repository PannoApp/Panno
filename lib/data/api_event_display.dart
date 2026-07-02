import '../core/interior_assets.dart';
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

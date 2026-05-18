import 'package:flutter/foundation.dart';
import '../data/events_news_data.dart';

/// Афиша и новости.
class EventsProvider extends ChangeNotifier {
  List<PiligrimEvent> _events = const [];
  List<PiligrimNewsPost> _news = const [];
  bool _loaded = false;

  List<PiligrimEvent> get events => _events;
  List<PiligrimNewsPost> get news => _news;
  bool get loaded => _loaded;

  List<PiligrimEvent> get upcomingEvents =>
      _events.where((e) => !e.isPast).toList();

  List<PiligrimEvent> get pastEvents => _events.where((e) => e.isPast).toList();

  Future<void> load() async {
    _events = List.unmodifiable(buildMockEvents());
    _news = List.unmodifiable(mockNewsPosts());
    _loaded = true;
    notifyListeners();
  }
}

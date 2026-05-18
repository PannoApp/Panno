import 'package:flutter/foundation.dart';

import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../data/repositories/events_repository.dart';

/// Афиша, архив и новости с API + fallback на моки.
class EventsProvider extends ChangeNotifier {
  EventsProvider({EventsRepository? repository})
      : _repository = repository ?? EventsRepository();

  final EventsRepository _repository;

  List<ApiEvent> upcoming = const [];
  List<ApiEvent> archived = const [];
  List<PiligrimNewsPost> news = const [];

  bool isLoadingUpcoming = false;
  bool isLoadingArchived = false;
  bool isLoadingNews = false;
  bool isReserving = false;

  String? upcomingError;
  String? archivedError;
  String? newsError;
  String? reserveError;

  bool _usedMockFallback = false;

  bool get usedMockFallback => _usedMockFallback;

  Future<void> loadUpcoming() async {
    if (isLoadingUpcoming) return;
    isLoadingUpcoming = true;
    upcomingError = null;
    notifyListeners();

    try {
      upcoming = upcomingApiSorted(await _repository.fetchUpcoming());
      _usedMockFallback = false;
    } catch (e) {
      upcomingError = e.toString();
      upcoming = upcomingApiSorted(mockEventsAsApi());
      _usedMockFallback = true;
    } finally {
      isLoadingUpcoming = false;
      notifyListeners();
    }
  }

  Future<void> loadArchived() async {
    if (isLoadingArchived) return;
    isLoadingArchived = true;
    archivedError = null;
    notifyListeners();

    try {
      archived = pastApiSorted(await _repository.fetchArchived());
    } catch (e) {
      archivedError = e.toString();
      archived = pastApiSorted(mockEventsAsApi());
      _usedMockFallback = true;
    } finally {
      isLoadingArchived = false;
      notifyListeners();
    }
  }

  Future<void> loadNews() async {
    if (isLoadingNews) return;
    isLoadingNews = true;
    newsError = null;
    notifyListeners();

    try {
      news = await _repository.fetchNews();
    } catch (e) {
      newsError = e.toString();
      news = List.unmodifiable(mockNewsPosts());
    } finally {
      isLoadingNews = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    await Future.wait([
      loadUpcoming(),
      loadArchived(),
      loadNews(),
    ]);
  }

  Future<void> reserveEvent(int eventId, int guestsCount) async {
    isReserving = true;
    reserveError = null;
    notifyListeners();

    try {
      await _repository.createReservation(
        eventId: eventId,
        guestsCount: guestsCount,
      );
    } catch (e) {
      reserveError = e.toString();
      rethrow;
    } finally {
      isReserving = false;
      notifyListeners();
    }
  }
}

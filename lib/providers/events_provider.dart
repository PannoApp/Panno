import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_errors.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../data/models/api_event_photo.dart';
import '../data/repositories/events_repository.dart';

/// Афиша, архив и новости с API + fallback на моки.
class EventsProvider extends ChangeNotifier {
  EventsProvider({EventsRepository? repository})
      : _repository = repository ?? EventsRepository();

  final EventsRepository _repository;
  final Map<int, String> _idempotencyKeys = {};

  List<ApiEvent> upcoming = const [];
  List<ApiEvent> archived = const [];
  List<PiligrimNewsPost> news = const [];

  bool isLoadingUpcoming = false;
  bool isLoadingArchived = false;
  bool isLoadingNews = false;
  bool isReserving = false;
  bool isLoadingPhotoReport = false;

  String? upcomingError;
  String? archivedError;
  String? newsError;
  String? reserveError;

  bool _usedMockFallback = false;

  List<ApiEventPhoto> _photoReport = const [];
  List<ApiEventPhoto> get photoReport => List.unmodifiable(_photoReport);

  bool get usedMockFallback => _usedMockFallback;

  Future<void> loadUpcoming() async {
    if (isLoadingUpcoming) return;
    isLoadingUpcoming = true;
    upcomingError = null;
    notifyListeners();

    try {
      upcoming = upcomingApiSorted(await _repository.fetchUpcoming());
      if (upcoming.isEmpty) {
        upcoming = upcomingApiSorted(mockEventsAsApi());
        _usedMockFallback = true;
      } else {
        _usedMockFallback = false;
      }
    } catch (e) {
      upcomingError = dioErrorMessage(e);
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
      if (archived.isEmpty) {
        archived = pastApiSorted(mockEventsAsApi());
        _usedMockFallback = true;
      }
    } catch (e) {
      archivedError = dioErrorMessage(e);
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
      if (news.isEmpty) {
        news = List.unmodifiable(mockNewsPosts());
        _usedMockFallback = true;
      }
    } catch (e) {
      newsError = dioErrorMessage(e);
      news = List.unmodifiable(mockNewsPosts());
      _usedMockFallback = true;
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

  Future<void> retry() => load();

  Future<void> loadPhotoReport(int eventId) async {
    isLoadingPhotoReport = true;
    notifyListeners();
    try {
      _photoReport = await _repository.fetchPhotoReport(eventId);
      if (_photoReport.isEmpty) {
        _photoReport = mockPhotoReportAsApi(eventId);
      }
    } catch (_) {
      _photoReport = mockPhotoReportAsApi(eventId);
    } finally {
      isLoadingPhotoReport = false;
      notifyListeners();
    }
  }

  Future<void> reserveEvent(int eventId, int guestsCount) async {
    isReserving = true;
    reserveError = null;
    notifyListeners();

    // Generates or retrieves a persistent Idempotency-Key per event reservation attempt
    final idempotencyKey =
        _idempotencyKeys.putIfAbsent(eventId, () => const Uuid().v4());

    try {
      await _repository.createReservation(
        eventId: eventId,
        guestsCount: guestsCount,
        idempotencyKey: idempotencyKey,
      );
      _idempotencyKeys.remove(eventId);
    } catch (e) {
      reserveError = dioErrorMessage(e);
      rethrow;
    } finally {
      isReserving = false;
      notifyListeners();
    }
  }
}

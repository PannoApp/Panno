import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_errors.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../data/models/api_event_photo.dart';
import '../data/repositories/events_repository.dart';

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

  List<ApiEventPhoto> _photoReport = const [];
  List<ApiEventPhoto> get photoReport => List.unmodifiable(_photoReport);

  Future<void> loadUpcoming() async {
    if (isLoadingUpcoming) return;
    isLoadingUpcoming = true;
    upcomingError = null;
    notifyListeners();

    try {
      upcoming = upcomingApiSorted(await _repository.fetchUpcoming());
    } catch (e) {
      upcomingError = dioErrorMessage(e);
      upcoming = const [];
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
      archivedError = dioErrorMessage(e);
      archived = const [];
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
      newsError = dioErrorMessage(e);
      news = const [];
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
    } catch (_) {
      _photoReport = const [];
    } finally {
      isLoadingPhotoReport = false;
      notifyListeners();
    }
  }

  Future<void> reserveEvent(int eventId, int guestsCount) async {
    isReserving = true;
    reserveError = null;
    notifyListeners();

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

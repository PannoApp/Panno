import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_errors.dart';
import '../data/api_event_display.dart';
import '../data/events_news_data.dart';
import '../data/models/api_event.dart';
import '../data/models/api_event_photo.dart';
import '../data/models/api_event_reservation.dart';
import '../data/repositories/event_reservation_repository.dart';
import '../data/repositories/events_repository.dart';

class EventsProvider extends ChangeNotifier {
  EventsProvider({
    EventsRepository? repository,
    EventReservationRepository? reservationRepository,
  })  : _repository = repository ?? EventsRepository(),
        _reservationRepository = reservationRepository ?? EventReservationRepository();

  final EventsRepository _repository;
  final EventReservationRepository _reservationRepository;
  final Map<int, String> _idempotencyKeys = {};

  List<ApiEvent> upcoming = const [];
  List<ApiEvent> archived = const [];
  List<PiligrimNewsPost> news = const [];

  bool isLoadingUpcoming = false;
  bool isLoadingArchived = false;
  bool isLoadingNews = false;
  bool isReserving = false;
  bool isLoadingPhotoReport = false;
  bool isOfflineMode = false;

  bool get _isRepoOffline {
    try {
      return _repository.isOfflineMode;
    } catch (_) {
      return false;
    }
  }

  String? upcomingError;
  String? archivedError;
  String? newsError;
  String? reserveError;
  String? photoReportError;

  List<ApiEventPhoto> _photoReport = const [];
  List<ApiEventPhoto> get photoReport => List.unmodifiable(_photoReport);
  int? _photoReportEventId;

  Future<void> loadUpcoming() async {
    if (isLoadingUpcoming) return;
    isLoadingUpcoming = true;
    upcomingError = null;
    notifyListeners();

    try {
      upcoming = upcomingApiSorted(await _repository.fetchUpcoming());
      isOfflineMode = _isRepoOffline;
    } catch (e) {
      upcomingError = dioErrorMessage(e);
      upcoming = const [];
      isOfflineMode = _isRepoOffline;
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
      isOfflineMode = _isRepoOffline;
    } catch (e) {
      archivedError = dioErrorMessage(e);
      archived = const [];
      isOfflineMode = _isRepoOffline;
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
      isOfflineMode = _isRepoOffline;
    } catch (e) {
      newsError = dioErrorMessage(e);
      news = const [];
      isOfflineMode = _isRepoOffline;
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

  Future<void> retryNews() => loadNews();

  Future<void> retryArchived() => loadArchived();

  Future<void> loadPhotoReport(int eventId) async {
    if (_photoReportEventId != eventId) {
      _photoReport = const [];
      photoReportError = null;
    }
    _photoReportEventId = eventId;

    isLoadingPhotoReport = true;
    photoReportError = null;
    notifyListeners();

    try {
      _photoReport = await _repository.fetchPhotoReport(eventId);
      photoReportError = null;
      isOfflineMode = _isRepoOffline;
    } catch (e) {
      photoReportError = dioErrorMessage(e);
      _photoReport = const [];
      isOfflineMode = _isRepoOffline;
    } finally {
      isLoadingPhotoReport = false;
      notifyListeners();
    }
  }

  Future<void> deletePhotoFromReport(int eventId, int photoId) async {
    await _repository.deletePhotoFromReport(eventId, photoId);
    _photoReport = _photoReport.where((p) => p.id != photoId).toList();
    notifyListeners();
    // Последнее фото отчёта удалено — обновляем hasPhotoReport в списке архива.
    if (_photoReport.isEmpty) {
      loadArchived();
    }
  }

  bool isUploadingPhoto = false;
  String? uploadPhotoError;

  /// Добавляет фото в фотоотчёт мероприятия. Возвращает false при ошибке
  /// ([uploadPhotoError] содержит текст для показа пользователю).
  Future<bool> addPhotoToReport(int eventId, File image) async {
    isUploadingPhoto = true;
    uploadPhotoError = null;
    notifyListeners();
    try {
      final photo = await _repository.addPhotoToReport(eventId, image);
      _photoReport = [..._photoReport, photo];
      loadArchived(); // обновить hasPhotoReport в списке архива
      return true;
    } catch (e) {
      uploadPhotoError = dioErrorMessage(e);
      return false;
    } finally {
      isUploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> deleteArchivedEvent(int eventId) async {
    await _repository.deleteEvent(eventId);
    archived = archived.where((e) => e.id != eventId).toList();
    notifyListeners();
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

  // ── Мои записи на мероприятия (EventReservationHistoryScreen) ───────────────

  List<ApiEventReservation> myReservations = const [];
  bool isLoadingMyReservations = false;
  String? myReservationsError;

  Future<void> loadMyReservations() async {
    isLoadingMyReservations = true;
    myReservationsError = null;
    notifyListeners();
    try {
      myReservations = await _reservationRepository.fetchMyReservations();
    } catch (e) {
      myReservationsError = dioErrorMessage(e);
      myReservations = const [];
    } finally {
      isLoadingMyReservations = false;
      notifyListeners();
    }
  }

  Future<void> retryMyReservations() => loadMyReservations();

  // ── Admin: мероприятия (EventEditScreen) ────────────────────────────────────

  bool isSavingEvent = false;
  String? saveEventError;

  Future<bool> createEvent(Map<String, dynamic> fields, {File? image}) async {
    isSavingEvent = true;
    saveEventError = null;
    notifyListeners();
    try {
      await _repository.createEvent(fields, image: image);
      load();
      return true;
    } on DioException catch (e) {
      saveEventError = adminSaveErrorMessage(e);
      return false;
    } catch (e) {
      saveEventError = 'Не удалось сохранить мероприятие: $e';
      return false;
    } finally {
      isSavingEvent = false;
      notifyListeners();
    }
  }

  Future<bool> updateEvent(int id, Map<String, dynamic> fields, {File? image}) async {
    isSavingEvent = true;
    saveEventError = null;
    notifyListeners();
    try {
      await _repository.updateEvent(id, fields, image: image);
      load();
      return true;
    } on DioException catch (e) {
      saveEventError = adminSaveErrorMessage(e);
      return false;
    } catch (e) {
      saveEventError = 'Не удалось сохранить мероприятие: $e';
      return false;
    } finally {
      isSavingEvent = false;
      notifyListeners();
    }
  }

  /// Удаление мероприятия из формы редактирования (в отличие от
  /// [deleteArchivedEvent] — обновляет все три списка, т.к. событие может
  /// быть как предстоящим, так и архивным).
  Future<bool> deleteEvent(int id) async {
    isSavingEvent = true;
    saveEventError = null;
    notifyListeners();
    try {
      await _repository.deleteEvent(id);
      load();
      return true;
    } on DioException catch (e) {
      saveEventError = adminDeleteErrorMessage(e, fallback: 'Не удалось удалить мероприятие');
      return false;
    } catch (e) {
      saveEventError = 'Ошибка при удалении: $e';
      return false;
    } finally {
      isSavingEvent = false;
      notifyListeners();
    }
  }

  // ── Admin: новости (NewsEditScreen) ──────────────────────────────────────────

  bool isSavingNews = false;
  String? saveNewsError;

  Future<bool> createNews(Map<String, dynamic> fields, {File? image}) async {
    isSavingNews = true;
    saveNewsError = null;
    notifyListeners();
    try {
      await _repository.createNews(fields, image: image);
      loadNews();
      return true;
    } on DioException catch (e) {
      saveNewsError = adminSaveErrorMessage(e);
      return false;
    } catch (e) {
      saveNewsError = 'Не удалось сохранить новость: $e';
      return false;
    } finally {
      isSavingNews = false;
      notifyListeners();
    }
  }

  Future<bool> updateNews(int id, Map<String, dynamic> fields, {File? image}) async {
    isSavingNews = true;
    saveNewsError = null;
    notifyListeners();
    try {
      await _repository.updateNews(id, fields, image: image);
      loadNews();
      return true;
    } on DioException catch (e) {
      saveNewsError = adminSaveErrorMessage(e);
      return false;
    } catch (e) {
      saveNewsError = 'Не удалось сохранить новость: $e';
      return false;
    } finally {
      isSavingNews = false;
      notifyListeners();
    }
  }

  Future<bool> deleteNews(int id) async {
    isSavingNews = true;
    saveNewsError = null;
    notifyListeners();
    try {
      await _repository.deleteNews(id);
      loadNews();
      return true;
    } on DioException catch (e) {
      saveNewsError = adminDeleteErrorMessage(e, fallback: 'Не удалось удалить новость');
      return false;
    } catch (e) {
      saveNewsError = 'Ошибка при удалении: $e';
      return false;
    } finally {
      isSavingNews = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_errors.dart';
import '../data/models/api_booking.dart';
import '../data/models/availability_slot.dart';
import '../data/models/booking_request.dart';
import '../data/models/booking_table.dart';
import '../data/models/booking_zone.dart';
import '../data/repositories/booking_repository.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  final BookingRepository _repository;
  String? _idempotencyKey;

  // Черновик формы (выбранные пользователем значения до отправки)
  BookingZone? selectedZone;
  int guests = 2;
  DateTime? visitDate;
  DateTime? visitTime;

  // Реальные залы ресторана из Remarked (см. GET /bookings/zones/) —
  // раньше тут был захардкоженный список main/terrace/private, не
  // совпадавший с реальными залами.
  List<BookingZone> zones = const [];
  bool isLoadingZones = false;
  String? zonesError;

  // Конкретный стол внутри выбранного зала (см. GET /bookings/tables/).
  // Появляется только после выбора зала; null означает «Любой стол».
  BookingTable? selectedTable;
  List<BookingTable> tables = const [];
  bool isLoadingTables = false;
  String? tablesError;

  // Состояние отправки заявки
  bool isSubmitting = false;
  bool isSuccess = false;
  String? error;

  // История бронирований текущего пользователя
  List<ApiBooking> history = const [];
  bool isLoadingHistory = false;
  String? historyError;

  // Проверка доступности слотов на выбранную дату/кол-во гостей/зал
  List<AvailabilitySlot> availabilitySlots = const [];
  bool isLoadingAvailability = false;
  String? availabilityError;

  void setZone(BookingZone? zone) {
    selectedZone = zone;
    selectedTable = null;
    tables = const [];
    tablesError = null;
    notifyListeners();
    loadAvailability();
    loadTables();
  }

  void setTable(BookingTable? table) {
    selectedTable = table;
    notifyListeners();
  }

  void setGuests(int count) {
    guests = count.clamp(1, 50);
    notifyListeners();
  }

  void setVisitDate(DateTime date) {
    visitDate = date;
    notifyListeners();
  }

  void setVisitTime(DateTime time) {
    visitTime = time;
    notifyListeners();
  }

  // Список залов не зависит от даты/гостей и меняется редко — грузим один
  // раз (экран вызывает это в initState). Недоступность Remarked не должна
  // ломать форму брони — просто выбор зала останется пустым (необязательное поле).
  Future<void> loadZones() async {
    if (isLoadingZones || zones.isNotEmpty) return;
    isLoadingZones = true;
    zonesError = null;
    notifyListeners();

    try {
      zones = await _repository.fetchZones();
    } catch (e) {
      zonesError = dioErrorMessage(e);
      zones = const [];
    } finally {
      isLoadingZones = false;
      notifyListeners();
    }
  }

  Future<void> loadAvailability() async {
    final date = visitDate;
    if (date == null || isLoadingAvailability) return;

    isLoadingAvailability = true;
    availabilityError = null;
    notifyListeners();

    try {
      availabilitySlots = await _repository.fetchAvailability(
        date: _formatDateForApi(date),
        guests: guests,
        zoneId: selectedZone?.id,
      );
    } catch (e) {
      availabilityError = dioErrorMessage(e);
      availabilitySlots = const [];
    } finally {
      isLoadingAvailability = false;
      notifyListeners();
    }
  }

  // Список свободных столов конкретного зала на точные дату/время/кол-во
  // гостей. Появляется только когда выбран зал — без зала «любой стол в
  // любом зале» подбирается backend'ом автоматически, как и раньше.
  Future<void> loadTables() async {
    final zone = selectedZone;
    final date = visitDate;
    final time = visitTime;
    if (zone == null || date == null || time == null) {
      if (tables.isNotEmpty || selectedTable != null) {
        tables = const [];
        selectedTable = null;
        notifyListeners();
      }
      return;
    }
    if (isLoadingTables) return;

    isLoadingTables = true;
    tablesError = null;
    notifyListeners();

    try {
      tables = await _repository.fetchTables(
        date: _formatDateForApi(date),
        time: _formatTimeForApi(time),
        guests: guests,
        zoneId: zone.id,
      );
      if (selectedTable != null &&
          !tables.any((t) => t.id == selectedTable!.id)) {
        selectedTable = null;
      }
    } catch (e) {
      tablesError = dioErrorMessage(e);
      tables = const [];
      selectedTable = null;
    } finally {
      isLoadingTables = false;
      notifyListeners();
    }
  }

  String _formatDateForApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTimeForApi(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> submitBooking(BookingRequest req) async {
    if (isSubmitting) return;
    isSubmitting = true;
    isSuccess = false;
    error = null;
    notifyListeners();

    // Генерируем Idempotency-Key для текущей отправки, если его еще нет.
    // Это гарантирует защиту от дубликатов при сетевых повторах (retry).
    _idempotencyKey ??= const Uuid().v4();

    try {
      await _repository.createBooking(
        req,
        idempotencyKey: _idempotencyKey!,
      );
      isSuccess = true;
      _resetForm();
      // Обновляем историю сразу — иначе счётчик «Бронирований» на экране
      // профиля (берёт данные из history) остаётся старым, пока гость сам
      // не откроет экран истории брони.
      loadHistory();
    } catch (e) {
      error = dioErrorMessage(e);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({int page = 1}) async {
    if (isLoadingHistory) return;
    isLoadingHistory = true;
    historyError = null;
    notifyListeners();

    try {
      history = await _repository.fetchHistory(page: page);
    } catch (e) {
      historyError = dioErrorMessage(e);
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  void resetSubmitState() {
    isSuccess = false;
    error = null;
    notifyListeners();
  }

  Future<void> retryHistory() => loadHistory();

  void _resetForm() {
    selectedZone = null;
    selectedTable = null;
    tables = const [];
    tablesError = null;
    guests = 2;
    visitDate = null;
    visitTime = null;
    _idempotencyKey = null;
    availabilitySlots = const [];
    availabilityError = null;
  }
}

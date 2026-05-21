import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_errors.dart';
import '../data/models/api_booking.dart';
import '../data/models/booking_request.dart';
import '../data/repositories/booking_repository.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  final BookingRepository _repository;
  String? _idempotencyKey;

  // Черновик формы (выбранные пользователем значения до отправки)
  String? selectedZone = 'Главный зал';
  int guests = 2;
  DateTime? visitDate;
  DateTime? visitTime;

  static const zones = ['Главный зал', 'Терраса', 'Приват'];

  // Состояние отправки заявки
  bool isSubmitting = false;
  bool isSuccess = false;
  String? error;

  // История бронирований текущего пользователя
  List<ApiBooking> history = const [];
  bool isLoadingHistory = false;
  String? historyError;

  void setZone(String? zone) {
    selectedZone = zone;
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
    selectedZone = 'Главный зал';
    guests = 2;
    visitDate = null;
    visitTime = null;
    _idempotencyKey = null;
  }
}

import 'package:flutter/foundation.dart';

/// Черновик заявки на бронь (общий state между экранами).
class BookingProvider extends ChangeNotifier {
  String? _selectedZone = 'Главный зал';
  int _guests = 2;
  DateTime? _visitDate;
  DateTime? _visitTime;

  static const zones = ['Главный зал', 'Терраса', 'Приват'];

  String? get selectedZone => _selectedZone;
  int get guests => _guests;
  DateTime? get visitDate => _visitDate;
  DateTime? get visitTime => _visitTime;

  void setZone(String? zone) {
    _selectedZone = zone;
    notifyListeners();
  }

  void setGuests(int count) {
    _guests = count.clamp(1, 20);
    notifyListeners();
  }

  void setVisitDate(DateTime date) {
    _visitDate = date;
    notifyListeners();
  }

  void setVisitTime(DateTime time) {
    _visitTime = time;
    notifyListeners();
  }

  void reset() {
    _selectedZone = 'Главный зал';
    _guests = 2;
    _visitDate = null;
    _visitTime = null;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../core/home_data.dart';

/// Ресторан, часы, контакты — общие данные приложения.
class CoreInfoProvider extends ChangeNotifier {
  RestaurantInfo _restaurant = kRestaurantInfo;
  bool _loaded = false;

  RestaurantInfo get restaurant => _restaurant;
  bool get loaded => _loaded;
  bool get isOpen => _restaurant.isOpen;

  Future<void> load() async {
    _restaurant = kRestaurantInfo;
    _loaded = true;
    notifyListeners();
  }
}

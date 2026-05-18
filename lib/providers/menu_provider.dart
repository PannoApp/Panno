import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/menu_data.dart' as menu_data;

enum MenuViewMode { feed, classic }

/// Меню: блюда, категории, режим ленты / классики.
class MenuProvider extends ChangeNotifier {
  List<menu_data.Dish> _dishes = List.unmodifiable(menu_data.kDishes);
  MenuViewMode _mode = MenuViewMode.feed;
  bool _loaded = false;

  List<menu_data.Dish> get dishes => _dishes;
  List<menu_data.DishCategory> get categories => menu_data.kDishCategories;
  MenuViewMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('menu_mode');
    _mode = saved == 'classic' ? MenuViewMode.classic : MenuViewMode.feed;
    _dishes = List.unmodifiable(menu_data.kDishes);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(MenuViewMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'menu_mode',
      mode == MenuViewMode.classic ? 'classic' : 'feed',
    );
    notifyListeners();
  }

  List<menu_data.Dish> dishesForCategory(String categoryId) =>
      menu_data.dishesByCategory(categoryId);
}

// MenuProvider — состояние меню: категории, блюда, пагинация, поиск, режим отображения.
// Подключён к MenuRepository; мок-данные не используются.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dio_errors.dart';
import '../data/models/api_category.dart';
import '../data/models/api_dish.dart';
import '../data/models/api_tag.dart';
import '../data/repositories/menu_repository.dart';

enum MenuViewMode { feed, classic }

class MenuProvider extends ChangeNotifier {
  MenuProvider({MenuRepository? repository})
      : _repository = repository ?? MenuRepository();

  final MenuRepository _repository;

  // ── Состояние ──────────────────────────────────────────────────────────────

  List<ApiCategory> categories = const [];
  List<ApiDish> dishes = const [];

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;
  bool isBootstrapping = false;
  String? bootstrapError;

  int _page = 1;
  int? activeCategoryId;
  String searchQuery = '';
  final List<int> activeTagIds = [];
  List<ApiTag> _allSeenTags = [];

  // Все теги с сервера (загружаются один раз при инициализации меню).
  List<ApiTag> allTags = const [];

  // ── Состояние видео-ленты (cursor pagination) ──────────────────────────────

  List<ApiDish> feedDishes = const [];

  /// Курсор следующей страницы; null — следующей страницы нет или ещё не загружали.
  String? _feedNextCursor;

  /// true, пока первая страница ленты ещё не загружена или идёт refresh.
  bool isLoadingFeed = false;

  /// true, если есть ещё страницы для подгрузки (курсор не null после первой загрузки).
  bool hasMoreFeed = true;
  String? feedError;

  MenuViewMode _mode = MenuViewMode.feed;
  bool _loaded = false;

  bool _globalMuted = true;
  bool get globalMuted => _globalMuted;
  void toggleGlobalMute() {
    _globalMuted = !_globalMuted;
    notifyListeners();
  }

  /// Индекс карточки в ленте после перехода из классического меню (см. [openFeedAtDish]).
  int? feedStartIndex;

  Timer? _debounce;

  // ── Геттеры ────────────────────────────────────────────────────────────────

  MenuViewMode get mode => _mode;
  bool get loaded => _loaded;

  // Теги для фильтр-чипов: серверный список если загружен, иначе производный из блюд.
  List<ApiTag> get availableTags {
    if (allTags.isNotEmpty) return allTags;
    if (activeTagIds.isNotEmpty && _allSeenTags.isNotEmpty) return _allSeenTags;
    final seen = <int>{};
    final result = <ApiTag>[];
    for (final dish in dishes) {
      for (final tag in dish.tags) {
        if (seen.add(tag.id)) result.add(tag);
      }
    }
    return result;
  }

  // ── Инициализация ──────────────────────────────────────────────────────────

  // Загружает сохранённый режим из SharedPreferences, затем параллельно
  // запрашивает категории, первую страницу блюд и первую страницу ленты.
  Future<void> load() async {
    isBootstrapping = true;
    bootstrapError = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('menu_mode');
    _mode = saved == 'classic' ? MenuViewMode.classic : MenuViewMode.feed;
    _loaded = true;
    notifyListeners();

    try {
      await Future.wait([
        loadCategories(),
        loadTags(),
        loadDishes(refresh: true),
        loadFeed(refresh: true),
      ]);
    } finally {
      isBootstrapping = false;
      _syncBootstrapError();
      notifyListeners();
    }
  }

  void _syncBootstrapError() {
    final hasDishes = dishes.isNotEmpty || feedDishes.isNotEmpty;
    if (hasDishes) {
      bootstrapError = null;
      return;
    }
    bootstrapError = error ?? feedError;
  }

  // ── Категории ──────────────────────────────────────────────────────────────

  Future<void> loadCategories() async {
    try {
      categories = await _repository.fetchCategories();
    } catch (_) {
      categories = const [];
    }
    notifyListeners();
  }

  Future<void> loadTags() async {
    try {
      allTags = await _repository.fetchTags();
    } catch (_) {
      allTags = const [];
    }
    notifyListeners();
  }

  // ── Блюда (с пагинацией) ───────────────────────────────────────────────────

  // refresh=true: сбросить страницу и список перед загрузкой.
  Future<void> loadDishes({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      dishes = const [];
      hasMore = true;
      error = null;
    }

    // Не запускать параллельных запросов одного типа.
    if (_page == 1 && isLoading) return;
    if (_page > 1 && isLoadingMore) return;
    if (!hasMore && !refresh) return;

    if (_page == 1) {
      isLoading = true;
    } else {
      isLoadingMore = true;
    }
    notifyListeners();

    try {
      final result = await _repository.fetchDishes(
        categoryId: activeCategoryId,
        tagIds: activeTagIds.isEmpty ? null : activeTagIds,
        search: searchQuery.isEmpty ? null : searchQuery,
        page: _page,
      );
      dishes = [...dishes, ...result.dishes];

      // Обновляем список всех виденных тегов только когда фильтр пуст,
      // чтобы чипы не исчезали при активации фильтрации.
      if (activeTagIds.isEmpty) {
        final seen = <int>{};
        final resultTags = <ApiTag>[];
        for (final dish in dishes) {
          for (final tag in dish.tags) {
            if (seen.add(tag.id)) resultTags.add(tag);
          }
        }
        _allSeenTags = resultTags;
      }

      hasMore = result.hasMore;
      _page++;
    } catch (e) {
      error = dioErrorMessage(e);
      hasMore = false;
    } finally {
      isLoading = false;
      isLoadingMore = false;
      if (!isBootstrapping) _syncBootstrapError();
      notifyListeners();
    }
  }

  // ── Видео-лента (cursor pagination) ───────────────────────────────────────

  /// refresh=true: сбрасывает курсор и список перед загрузкой первой страницы.
  /// Повторный вызов без refresh подгружает следующую страницу по сохранённому курсору.
  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      _feedNextCursor = null;
      feedDishes = const [];
      hasMoreFeed = true;
      feedError = null;
    }

    // Не запускать параллельных запросов и не грузить, если страниц больше нет.
    if (isLoadingFeed) return;
    if (!hasMoreFeed && !refresh) return;

    isLoadingFeed = true;
    notifyListeners();

    try {
      final result = await _repository.fetchFeed(cursor: _feedNextCursor);
      feedDishes = [...feedDishes, ...result.dishes];
      _feedNextCursor = result.nextCursor;
      hasMoreFeed = result.nextCursor != null;
    } catch (e) {
      feedError = dioErrorMessage(e);
      hasMoreFeed = false;
    } finally {
      isLoadingFeed = false;
      if (!isBootstrapping) _syncBootstrapError();
      notifyListeners();
    }
  }

  Future<void> retry() async {
    bootstrapError = null;
    error = null;
    feedError = null;
    await load();
  }

  // ── С главной (Путь героя / быстрые действия) ───────────────────────────────

  /// Полное меню: видео-лента, без фильтра категории (ТЗ: лента по умолчанию).
  Future<void> openMenuBrowseAll() async {
    await setMode(MenuViewMode.feed);
    setCategory(null);
  }

  /// «Путь героя» в меню: классический режим + категория по подстроке имени (RU).
  Future<void> openMenuPathCategory(String nameHintRu) async {
    await setMode(MenuViewMode.classic);
    final hint = nameHintRu.toLowerCase().trim();
    if (hint.isEmpty) {
      setCategory(null);
      return;
    }
    int? id;
    for (final c in categories) {
      if (c.name.toLowerCase().contains(hint)) {
        id = c.id;
        break;
      }
    }
    setCategory(id);
  }

  // ── Фильтры ────────────────────────────────────────────────────────────────

  // Выбор категории — сброс и перезагрузка.
  void setCategory(int? id) {
    if (activeCategoryId == id) return;
    activeCategoryId = id;
    activeTagIds.clear();
    _allSeenTags.clear();
    loadDishes(refresh: true);
  }

  void toggleTag(int tagId) {
    if (activeTagIds.contains(tagId)) {
      activeTagIds.remove(tagId);
    } else {
      activeTagIds.add(tagId);
    }
    loadDishes(refresh: true);
  }

  void clearTags() {
    if (activeTagIds.isEmpty) return;
    activeTagIds.clear();
    loadDishes(refresh: true);
  }

  // Поиск с debounce 400 мс — избегаем лишних запросов при быстром вводе.
  void setSearch(String q) {
    _debounce?.cancel();
    searchQuery = q;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      loadDishes(refresh: true);
    });
  }

  // ── Режим отображения (feed / classic) ─────────────────────────────────────

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

  /// Классическое меню → полноэкранное видео блюда в режиме «Видео».
  Future<void> openFeedAtDish(int dishId) async {
    await setMode(MenuViewMode.feed);
    var idx = feedDishes.indexWhere((d) => d.id == dishId);
    if (idx < 0) {
      await loadFeed(refresh: true);
      idx = feedDishes.indexWhere((d) => d.id == dishId);
    }
    feedStartIndex = idx >= 0 ? idx : 0;
    notifyListeners();
  }

  void clearFeedStartIndex() {
    if (feedStartIndex == null) return;
    feedStartIndex = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

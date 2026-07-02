# Menu — документация (Блок 5)

## Обзор

Экран меню работает в двух режимах:

| Режим | Ключ | Описание |
|---|---|---|
| **Путь** (feed) | `MenuViewMode.feed` | Reels-style вертикальная лента, полноэкранные карточки |
| **Свиток** (classic) | `MenuViewMode.classic` | Список с поиском, категориями и тегами |

Переключение сохраняется в `SharedPreferences` (ключ `'menu_mode'`). Управляется через `MenuProvider`.

---

## MenuProvider

**Файл:** `lib/providers/menu_provider.dart`

### Состояние

| Поле | Тип | Описание |
|---|---|---|
| `categories` | `List<ApiCategory>` | Список категорий с сервера |
| `dishes` | `List<ApiDish>` | Накопленный список блюд (пагинация) |
| `isLoading` | `bool` | Идёт загрузка первой страницы |
| `isLoadingMore` | `bool` | Идёт загрузка следующей страницы |
| `hasMore` | `bool` | Есть ли ещё страницы |
| `activeCategoryId` | `int?` | Выбранная категория (null = все) |
| `searchQuery` | `String` | Текущий поисковый запрос |
| `mode` | `MenuViewMode` | Режим отображения (feed / classic) |
| `loaded` | `bool` | Первичная инициализация завершена |

### Методы

| Метод | Описание |
|---|---|
| `load()` | Загружает mode из prefs, затем категории и первую страницу блюд |
| `loadCategories()` | GET `/menu/categories/` → `categories` |
| `loadDishes({bool refresh})` | Загружает блюда; `refresh: true` сбрасывает страницу и список |
| `setCategory(int? id)` | Устанавливает `activeCategoryId`, сбрасывает и перезагружает |
| `setSearch(String q)` | Устанавливает `searchQuery` с debounce 400 мс, затем перезагружает |
| `setMode(MenuViewMode)` | Меняет режим, сохраняет в SharedPreferences |

### Пример использования

```dart
// Чтение состояния
final provider = context.watch<MenuProvider>();
final dishes = provider.dishes;

// Вызов действий
context.read<MenuProvider>().setCategory(3);
context.read<MenuProvider>().setSearch('манты');
context.read<MenuProvider>().loadDishes(); // подгрузить следующую страницу
```

---

## Пагинация (инфинит-скролл)

Работает только в классическом режиме. Механизм:

1. `_ClassicMenuSectionState` слушает `ScrollController`
2. При приближении к концу на 200 px: `provider.loadDishes()` (без `refresh`)
3. `MenuProvider.loadDishes()` отправляет запрос на следующую страницу и **добавляет** результаты к `dishes`
4. Когда `hasMore == false` — загрузка прекращается

```
Page 1 → dishes = [d1, d2, d3]
Page 2 → dishes = [d1, d2, d3, d4, d5, d6]
...
hasMore = false → loadDishes() игнорирует вызов
```

---

## MenuRepository

**Файл:** `lib/data/repositories/menu_repository.dart`

```dart
// Получить все категории
Future<List<ApiCategory>> fetchCategories()

// Получить страницу блюд с фильтрами
Future<({List<ApiDish> dishes, bool hasMore})> fetchDishes({
  int? categoryId,
  List<int>? tagIds,
  String? search,
  int page = 1,
})
```

Endpoints:
- `GET /menu/categories/` — список категорий (DRF пагинация)
- `GET /menu/dishes/` — блюда с параметрами `category_id`, `tags`, `search`, `page`

---

## Как добавить новый тег или фильтр

1. Добавить значение в `DishTag` enum в `lib/core/menu_data.dart`
2. Добавить соответствующие `label`, `iconAsset`, `color` в `DishTagX` extension
3. Добавить тег в список `_FilterChips._filters` в `lib/screens/menu_screen.dart`
4. Бэкенд должен возвращать тег в `ApiDish.tags` как строку с именем enum-значения (например, `'signature'`)

Парсинг строк из API в `DishTag`: `DishTagHelper.fromStringList(dish.tags)` из `lib/core/menu_data.dart`.

---

## DishVideoCard — жизненный цикл VideoPlayerController

**Файл:** `lib/widgets/dish_video_card.dart`

```
initState():
  if dish.videoUrl != null → _initVideo(url)
    VideoPlayerController.networkUrl(url)
    .initialize()
    .setLooping(true)
    .addListener(setState)  ← перестройка при буферизации
    if mounted: setState(() => _videoCtrl = ctrl)
    if isActive: ctrl.play()

didUpdateWidget():
  isActive true → false:
    _ambientCtrl.stop()
    _videoCtrl?.pause()   ← пауза, не dispose (быстрое возобновление)
  isActive false → true:
    _ambientCtrl.repeat()
    _videoCtrl?.play()

dispose():
  _ambientCtrl.dispose()
  _videoCtrl?.dispose()   ← окончательная очистка
```

**Fallback:** если `videoUrl == null` или инициализация не удалась — отображается `_CinematicBackground` (анимированный градиент).

---

## Изображения блюд (CachedNetworkImage)

В детальном листе (`_DishDetailSheet`) используется `DishThumbnail` из `lib/widgets/dish_elements.dart`:

```dart
DishThumbnail(
  imageUrl: dish.imageUrl,   // null → fallback
  fallback: const SomeFallbackWidget(),
  height: 180,
)
```

`CachedNetworkImage` кэширует изображения локально. При ошибке загрузки или `imageUrl == null` показывается `fallback` виджет.

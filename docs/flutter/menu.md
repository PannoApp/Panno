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
| `dishes` | `List<ApiDish>` | Накопленный список блюд классического режима (пагинация) |
| `isLoading` | `bool` | Идёт загрузка первой страницы (classic) |
| `isLoadingMore` | `bool` | Идёт загрузка следующей страницы (classic) |
| `hasMore` | `bool` | Есть ли ещё страницы (classic) |
| `error` | `String?` | Текст ошибки последней загрузки блюд (classic) |
| `activeCategoryId` | `int?` | Выбранная категория (null = все) |
| `activeTagIds` | `List<int>` | Выбранные ID тегов-фильтров (classic) |
| `allTags` | `List<ApiTag>` | Все теги с сервера, GET `/menu/tags/` (для чипов-фильтров и формы блюда) |
| `availableTags` | `List<ApiTag>` (геттер) | `allTags`, если загружены; иначе теги, реально встреченные в `dishes` |
| `searchQuery` | `String` | Текущий поисковый запрос |
| `mode` | `MenuViewMode` | Режим отображения (feed / classic) |
| `loaded` | `bool` | Первичная инициализация (mode из prefs) завершена |
| `isBootstrapping` | `bool` | Идёт первичная загрузка `load()` (категории + теги + обе ленты параллельно) |
| `bootstrapError` | `String?` | Ошибка бутстрапа — выставляется, только если после `load()`/подгрузки нет блюд ни в `dishes`, ни в `feedDishes` |
| `globalMuted` | `bool` | Глобальный флаг «звук выключен» для видео-ленты |
| `feedDishes` | `List<ApiDish>` | Накопленный список блюд видео-ленты (cursor-пагинация) |
| `isLoadingFeed` | `bool` | Идёт загрузка страницы ленты |
| `hasMoreFeed` | `bool` | Есть ли ещё страницы ленты (курсор не `null`) |
| `feedError` | `String?` | Текст ошибки последней загрузки ленты |
| `feedStartIndex` | `int?` | Индекс карточки, на которую нужно проскроллить ленту после перехода из классического меню (см. `openFeedAtDish`) |
| `allergens` | `List<ApiAllergen>` | Справочник аллергенов для формы `DishEditScreen`, GET `/menu/allergens/` |
| `isLoadingDishMetadata` | `bool` | Идёт загрузка тегов+аллергенов для формы блюда |
| `isSavingDish` / `saveDishError` | `bool` / `String?` | Статус сохранения/удаления блюда в `DishEditScreen` |

### Методы

| Метод | Описание |
|---|---|
| `load()` | Загружает mode из prefs, затем параллельно: категории, теги, первую страницу `dishes` и первую страницу `feedDishes` |
| `loadCategories()` | GET `/menu/categories/` → `categories` |
| `loadTags()` | GET `/menu/tags/` → `allTags` |
| `loadDishes({bool refresh})` | Классический режим: загружает блюда с учётом `activeCategoryId`/`activeTagIds`/`searchQuery`; `refresh: true` сбрасывает страницу и список |
| `loadFeed({bool refresh})` | Видео-лента: подгружает следующую страницу по сохранённому курсору; `refresh: true` сбрасывает курсор и `feedDishes` |
| `retry()` | Сбрасывает все ошибки и заново вызывает `load()` (кнопка «Повторить» при пустом бутстрапе) |
| `setCategory(int? id)` | Устанавливает `activeCategoryId`, сбрасывает теги и перезагружает `dishes` |
| `toggleTag(int tagId)` | Добавляет/убирает тег из `activeTagIds`, перезагружает `dishes` |
| `clearTags()` | Очищает `activeTagIds`, перезагружает `dishes` |
| `setSearch(String q)` | Устанавливает `searchQuery` с debounce 400 мс, затем перезагружает `dishes` |
| `setMode(MenuViewMode)` | Меняет режим, сохраняет в SharedPreferences |
| `toggleGlobalMute()` | Переключает `globalMuted` (звук видео-ленты) |
| `openMenuBrowseAll()` | Переключает в feed-режим и сбрасывает категорию — «Показать всё меню» |
| `openMenuPathCategory(String nameHintRu)` | Переключает в classic-режим и выбирает категорию по подстроке названия (RU) — используется в «Путь героя» на главном экране |
| `openFeedAtDish(int dishId)` | Переключает в feed-режим и выставляет `feedStartIndex` на карточку блюда (дозагружает ленту, если блюда ещё нет) — переход из классического меню в видео |
| `clearFeedStartIndex()` | Сбрасывает `feedStartIndex` после того, как лента проскроллила к нужной карточке |
| `loadDishMetadata()` | Загружает `allTags` и `allergens` для формы `DishEditScreen` (ошибка не блокирует форму) |
| `createDish(fields, {image, video})` | POST `/menu/staff/dishes/{id}/` через `MenuRepository.createDish`; при успехе триггерит `load()` |
| `updateDish(id, fields, {image, video})` | PATCH `/menu/staff/dishes/{id}/` |
| `deleteDish(id)` | DELETE `/menu/staff/dishes/{id}/` |
| `fetchDishDetail(id)` | GET `/menu/dishes/{id}/` — полные данные блюда (теги, аллергены) для `DishDetailSheet`; при ошибке возвращает `null` |

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

Пагинация работает в обоих режимах, но по-разному устроена.

### Классический режим — постраничная (page-based)

1. `_ClassicMenuSectionState` слушает `ScrollController`
2. При приближении к концу на 200 px: `provider.loadDishes()` (без `refresh`)
3. `MenuProvider.loadDishes()` отправляет запрос на следующую страницу (`page`) и **добавляет** результаты к `dishes`
4. Когда `hasMore == false` — загрузка прекращается

```
Page 1 → dishes = [d1, d2, d3]
Page 2 → dishes = [d1, d2, d3, d4, d5, d6]
...
hasMore = false → loadDishes() игнорирует вызов
```

### Видео-лента (feed) — курсорная (cursor-based)

1. Лента слушает приближение к концу списка `feedDishes` и вызывает `provider.loadFeed()` (без `refresh`)
2. `MenuProvider.loadFeed()` отправляет запрос GET `/menu/feed/` с параметром `cursor` (курсор из предыдущего ответа; `null` — первая страница) и **добавляет** результаты к `feedDishes`
3. Курсор следующей страницы сохраняется в `_feedNextCursor`; `hasMoreFeed` истинно, пока сервер возвращает непустой `next_cursor`
4. Когда `hasMoreFeed == false` — загрузка прекращается

Механизм соответствует курсорной пагинации бэкенда `GET /menu/feed/` (см. `backend/docs/menu.md`) и парсится через `PaginatedResponse.parseCursor` в `MenuRepository.fetchFeed`.

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

## Детальный лист блюда (DishDetailSheet)

**Файл:** `lib/widgets/dish_detail_sheet.dart`

`DishDetailSheet` — публичный `StatefulWidget`, единый bottom sheet для блюда, используемый и из фото-ленты (classic), и из видео-ленты (feed). `ClassicDishDetailSheet` — тонкий алиас (`extends DishDetailSheet`), сохранён для обратной совместимости вызывающего кода; поведение идентично.

- `DraggableScrollableSheet` (`initialChildSize: 0.88`, `minChildSize: 0.4`), hero-изображение через `CachedNetworkImage` (не через `DishThumbnail` — этот виджет здесь больше не используется), фолбэк — `DishClassicThumbnailFallback` (SVG-тотем на фоне `earthWarm`)
- В `initState` сохраняет `widget.dish` в локальный `_dish`; если у блюда пустые `tags` **и** `allergens`, вызывает `_fetchFull()`
- `_fetchFull()` вызывает `context.read<MenuProvider>().fetchDishDetail(dish.id)` (GET `/menu/dishes/{id}/`) и, если ответ не `null`, обновляет `_dish` через `setState` — это дозагрузка полных данных, т.к. list-эндпоинты (`/menu/dishes/`, `/menu/feed/`) могут не включать вложенные теги/аллергены
- Контент: описание, теги (`DishDetailTagsRow`), история блюда (`_DishStoryBlock`, курсив с левым акцентом), аллергены (`_DishAllergensBlock`, pill-чипы) — каждый блок рендерится, только если соответствующее поле непустое

`CachedNetworkImage` кэширует изображения локально; при ошибке загрузки или `imageUrl == null` показывается фолбэк-виджет.

---

## Admin: редактирование блюда

**Файл:** `lib/screens/dish_edit_screen.dart`

Полноценная форма создания/редактирования блюда для персонала. `DishEditScreen(dish: null, categories: ...)` — режим создания; `DishEditScreen(dish: someDish, categories: ...)` — режим редактирования.

### Поля формы

- Фото блюда — выбор из галереи + кадрирование 16:9 (`image_cropper`), live-превью карточки блюда
- Видео для ленты (9:16) — выбор из галереи (`ImagePicker.pickVideo`, до 5 минут); если у существующего блюда уже есть видео, показывается бейдж статуса: **ГОТОВО** (`ready`) / **ОБРАБАТЫВАЕТСЯ** (`processing`) / **ОШИБКА** (`failed`) / **ОЖИДАЕТ** (иное значение, включая `pending`)
- Название *, Цена (₸) *, Категория * (выпадающий список из переданных `categories`), Вес, Описание, История блюда (легенда)
- Теги и аллергены — чипы множественного выбора (`_SelectableChip`), источники — `MenuProvider.allTags` / `MenuProvider.allergens`, подгружаются через `loadDishMetadata()` в `initState`
- Переключатель «Отображать в меню» (`is_active`)

При редактировании существующего блюда текстовые аллергены (`ApiDish.allergens` — список строк) один раз сопоставляются по имени со справочником (`_preselectAllergensOnce`), как только справочник аллергенов загрузится.

### Сохранение и удаление

- Кнопка «ОПУБЛИКОВАТЬ» / «СОХРАНИТЬ ИЗМЕНЕНИЯ» вызывает `MenuProvider.createDish(fields, image:, video:)` или `MenuProvider.updateDish(id, fields, image:, video:)`
- Значок удаления в AppBar (только в режиме редактирования) открывает диалог подтверждения → `MenuProvider.deleteDish(id)`
- Оба пути шлют запросы через `MenuRepository` на `POST/PATCH/DELETE /menu/staff/dishes/{id}/`; при ошибке экран показывает `PiligrimToast` с текстом из `saveDishError`

### Точка входа

Экран открывается из `lib/screens/menu_screen.dart` через FAB, видимый только когда `isClassic && AuthProvider.isAdmin` (классический режим + права администратора/персонала), а также из карточки блюда в классическом меню (кнопка редактирования при `isAdmin`).

### Тесты

```bash
flutter test test/screens/dish_edit_screen_test.dart
flutter test test/widgets/dish_edit_screen_test.dart
```

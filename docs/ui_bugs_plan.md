# План исправления UI-багов — Piligrim

> Составлен: 2026-05-28  
> Ветка: `flutter-dev`

---

## Порядок исполнения (рекомендованный)

| Приоритет | Баги | Сложность |
|---|---|---|
| 🔴 Критичные | #1 (видео), #9 (интерьер) | Средняя |
| 🟡 Важные | #2 (линия), #5 (кнопки), #8 (карточки событий) | Лёгкая–Средняя |
| 🟢 Улучшения | #3 (звук), #6 (С нами), #7 (тег) | Лёгкая |
| 🔵 Новый функционал | #4 (КБЖУ) | Backend + Frontend |

---

## Баг #1 — Видео в меню выходит за экран на Android

**Корень проблемы:** В `main.dart:35` включён `SystemUiMode.edgeToEdge`, а в `main.dart:210` у `RootShell` стоит `extendBody: true`. Тело `IndexedStack` занимает **полную высоту экрана**, включая зону за нижним системным nav-bar'ом. `_VideoFeedSection` → `PageView` → `DishVideoCard` получают эту полную высоту, и видео рендерится за нижней шторкой Android. На iOS та же схема выглядит нормально (Home Indicator прозрачный), а на Android с кнопочной навигацией получается жёсткий обрез.

**Файлы:** `lib/screens/menu_screen.dart` → класс `_VideoFeedSection` (~строки 387–424)

**Fix:** В `_VideoFeedSection.build`, внутри `PageView.itemBuilder`, обернуть `DishVideoCard` в `SizedBox` с явной высотой экрана:

```dart
itemBuilder: (_, i) {
  final screenH = MediaQuery.sizeOf(context).height;
  return SizedBox(
    height: screenH,
    child: DishVideoCard(
      dish: dishes[i],
      isActive: i == _currentPage && widget.isTabActive,
    ),
  );
},
```

**Тест симулятор (iOS):** Открыть меню → режим «Видео» → прокрутить 3–4 карточки. Убедиться, что видео заполняет экран без пустых полос.

**Тест физ. Android:** Тот же сценарий. Проверить с режимом кнопочной навигации (3 кнопки) И жестовой навигацией. Видео должно занимать весь экран; текст блюда должен быть выше нижней панели навигации (за счёт `viewPaddingOf.bottom`, который уже реализован в `_buildBottomInfoText`).

---

## Баг #2 — Горизонтальная линия в карточке бронирования

**Корень проблемы:** В `lib/screens/booking_history_screen.dart:173` используется `const Divider(height: 1, color: PiligrimColors.divider)`. Flutter-виджет `Divider` с `height: 1` создаёт жёсткий 1px пиксель. Остальные разделители в приложении используют `_ProfileHairlineDivider` (0.5px, `alpha: 0.10`) или градиентные линии. На Android нет субпиксельного сглаживания как на iOS Retina — линия особенно заметна.

**Fix:** В `_BookingCard.build` (строка 173) заменить:

```dart
// Было:
const Divider(height: 1, color: PiligrimColors.divider),

// Стало:
Container(
  height: 0.5,
  color: PiligrimColors.sky.withValues(alpha: 0.10),
),
```

**Тест симулятор:** Профиль → нажать «Бронирования» → проверить карточки. Линия должна быть еле различима (hairline), соответствуя стилю карточек уведомлений и контактов в профиле.

**Тест физ. Android:** Аналогично. Прокрутить вниз по истории бронирований — никаких видимых жёстких делителей.

---

## Баг #3 — Звук отключается только для одного видео

**Корень проблемы:** `_isMuted` объявлен локально в `_DishVideoCardState` (`dish_video_card.dart:36`). При свайпе на следующую карточку создаётся новый `State` с `_isMuted = true` (muted by default). Если пользователь снял мут на карточке 1 и свайпнул на карточку 2 — карточка 2 снова замьючена.

**Fix:** Вынести состояние мута в `MenuProvider` как `bool globalMuted` (по умолчанию `true`).

**1. `lib/providers/menu_provider.dart`** — добавить:

```dart
bool _globalMuted = true;
bool get globalMuted => _globalMuted;

void toggleGlobalMute() {
  _globalMuted = !_globalMuted;
  notifyListeners();
}
```

**2. `lib/widgets/dish_video_card.dart`** — убрать локальный `_isMuted`, читать из провайдера:

```dart
// В _toggleMute():
context.read<MenuProvider>().toggleGlobalMute();

// В _MuteButton — передавать значение из Provider:
_MuteButton(
  isMuted: context.watch<MenuProvider>().globalMuted,
  onToggle: _toggleMute,
)
```

При `didUpdateWidget` (карточка стала активной) и при инициализации видео (`_initVideo`) — применять текущий `globalMuted` к `_videoCtrl`.

**Тест симулятор:** Открыть меню видео → нажать кнопку звука → свайпнуть на следующее видео. Звук должен остаться включённым.

**Тест физ. Android:** Тот же сценарий. Проверить 5–6 карточек подряд после включения звука.

---

## Баг #4 — Добавить КБЖУ

**Корень проблемы:** `ApiDish` (`lib/data/models/api_dish.dart`) не имеет полей `calories`, `proteins`, `fats`, `carbs`. Django-модель нужно расширить.

### Этап A — Backend

1. В `backend/apps/menu/models.py`: добавить поля:
   ```python
   calories = models.DecimalField(max_digits=7, decimal_places=1, null=True, blank=True)
   proteins = models.DecimalField(max_digits=7, decimal_places=1, null=True, blank=True)
   fats = models.DecimalField(max_digits=7, decimal_places=1, null=True, blank=True)
   carbs = models.DecimalField(max_digits=7, decimal_places=1, null=True, blank=True)
   ```
2. `makemigrations menu`, `migrate`
3. В `menu/serializers.py`: добавить поля в `DishSerializer`
4. Обновить `backend/docs/menu.md` и `backend/API_FOR_FLUTTER.md`

### Этап B — Frontend

1. В `lib/data/models/api_dish.dart`: добавить поля и парсинг:
   ```dart
   final double? calories;
   final double? proteins;
   final double? fats;
   final double? carbs;
   // В fromJson():
   calories: parseDoubleOrNull(json['calories']),
   proteins: parseDoubleOrNull(json['proteins']),
   fats: parseDoubleOrNull(json['fats']),
   carbs: parseDoubleOrNull(json['carbs']),
   ```
2. В `lib/widgets/dish_detail_sheet.dart` — добавить блок КБЖУ под весом: 4 горизонтальных чипа (ккал / белки / жиры / углеводы), аналог `DishInfoChip`. Блок скрыт если все 4 поля `null`.
3. В `lib/widgets/dish_video_card.dart` — опционально: мини-строка КБЖУ под весом в `_buildBottomInfoText`.

**Тест:** Добавить через Django admin блюдо с КБЖУ → открыть детальный лист → проверить отображение. Проверить пустое состояние (КБЖУ не заполнено — блок скрыт).

**Тест физ. Android:** Тот же сценарий. Проверить шрифт и отступы на маленьком экране (5.5").

---

## Баг #5 — Разные кнопки «Назад»

**Корень проблемы:** Три разных стиля в разных экранах:

| Экран | Текущий стиль |
|---|---|
| `booking_history_screen.dart:67` | `PiligrimNavButton` (круглая иконка, без текста) ✅ |
| `event_detail_screen.dart:80` | SVG + «Назад» текст (iOS-стиль) ❌ |
| `booking_screen.dart:225` | `arrow_back_ios_new_rounded` + «Назад» ❌ |
| `interior_photo_viewer.dart:137` | `PiligrimNavButton` ✅ |
| `tour_webview_screen.dart:60` | `IconButton` (Material default!) ❌ |

**Стандарт:** `PiligrimNavButton(icon: Icons.chevron_left, onTap: ...)` из `lib/widgets/piligrim_nav_button.dart`.

**Fix:** Привести все экраны к стандарту:

1. **`event_detail_screen.dart`** (строки 78–115) — заменить `PiligrimTap` + SVG + текст на `PiligrimNavButton`. Уменьшить `leadingWidth: 108` → `leadingWidth: 56`.

2. **`booking_screen.dart`** (~строка 225) — заменить inline-кнопку на `PiligrimNavButton`.

3. **`tour_webview_screen.dart`** (строка 60) — заменить `IconButton` на `PiligrimNavButton`.

4. **`event_edit_screen.dart`**, **`dish_edit_screen.dart`**, **`news_edit_screen.dart`**, **`event_photo_report_screen.dart`**, **`phone_entry_screen.dart`** — в AppBar `leading` можно оставить `PiligrimTap` (edit-контекст отличается от навигационного).

**Тест симулятор:** Пройтись по всем push-экранам: история бронирований, детали события, экран бронирования, 3D-тур. Кнопки назад должны выглядеть одинаково.

**Тест физ. Android:** Tap-target кнопки должен быть удобным. Проверить, что 44×44dp tap-area сохраняется.

---

## Баг #6 — Третья карточка «С нами» другой формы

**Корень проблемы:** В `_StatsRow` (`profile_screen.dart:494`) три карточки — `Expanded` в `Row`. Все три используют `_ProfileGlassCard(variant: ProfileGlassVariant.stat)` → `BorderRadius.circular(14)`. Визуальная разница возникает из-за `small: true` → `fontSize: 14` для даты vs `20` для чисел. Дата типа «Март 2024» не масштабируется через `FittedBox` в маленькой карточке корректно, создавая впечатление другого макета.

**Fix:** Для карточки «С нами» при `small: true` — заменить `FittedBox` на `Text` с `overflow: TextOverflow.ellipsis, maxLines: 1`. Добавить мини-иконку для визуальной согласованности:

```dart
// В _StatCard.build, ветка small: true:
Icon(Icons.calendar_today_outlined, size: 11, color: PiligrimColors.steppe.withValues(alpha: 0.55)),
const SizedBox(height: 3),
Text(
  value,
  style: PiligrimTextStyles.caption.copyWith(
    fontSize: 11,
    color: PiligrimColors.steppe,
    fontWeight: FontWeight.w700,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

**Тест симулятор:** Профиль залогиненного пользователя → три карточки должны быть визуально одинакового размера и формы, различаться только содержимым.

**Тест физ. Android:** Проверить на маленьком экране (5"). Карточки не должны «съёживаться» или выглядеть деформированными.

---

## Баг #7 — Тег «Острое» красится иначе чем остальные

**Корень проблемы:** В `lib/core/menu_data.dart:26`, `tagSpicy = Color(0xFFD67845)` (оранжево-красный). Незарегистрированные теги используют `kDefaultTagStyle.color = PiligrimColors.water` (голубой). «Острое» выбивается из ряда, потому что новые пользовательские теги все получают голубой цвет по умолчанию.

**Варианты Fix:**

**Вариант A (рекомендованный):** Убедиться, что все часто используемые теги зарегистрированы в реестре `_kTagStyles`. Добавить теги, которые создаются в панели управления (уточнить список у пользователя). Тег «Острое» оставить оранжевым — семантически верно (огонь = spicy).

**Вариант B:** Если единообразие важнее семантики — изменить `tagSpicy` на `steppe`-цвет:
```dart
'острое': TagStyle(iconAsset: 'assets/images/luk.svg', color: PiligrimColors.steppe),
```

**Тест:** Открыть блюда с тегом «Острое» и другими тегами → чипы должны выглядеть согласованно с общим стилем карточек меню.

---

## Баг #8 — Карточки мероприятий в Афише ≠ главной

**Корень проблемы:**
- **Главная** (`home_event_block.dart:133`): `_EventCard` = полноразмерный постер `AspectRatio(1.25)`, full-bleed cover, крупный заголовок, steppe-кнопка CTA.
- **Афиша** (`events_screen.dart:893`): `_EventListCard` = горизонтальная строка с маленьким превью 100×124 + текст справа.

**Fix:** Переработать `_EventListCard` в стиль `_EventCard`:

- `Container` с `AspectRatio(aspectRatio: 1.6)` (чуть шире главной для ленты)
- `ClipRRect(borderRadius: BorderRadius.circular(14))`
- `EventCoverImage` как full-bleed background
- Многоступенчатый градиент снизу (аналогично `home_event_block.dart`)
- Water-pill даты (top-left), format-badge (top-right) — переиспользовать существующие `_DateBadge` и `_FormatBadge`
- Текст заголовка + дата + цена снизу в `Padding(fromLTRB(14, 0, 14, 14))`
- Steppe-левая акцентная полоса: `Container(width: 3, color: PiligrimColors.steppe.withValues(alpha: 0.8))`

**Тест симулятор:** Афиша → список событий. Карточки должны выглядеть как крупные постеры, как в HomeScreen.

**Тест физ. Android:** Прокрутить афишу, убедиться в плавности скролла. Проверить, что обложки загружаются корректно (`CachedNetworkImage`).

---

## Баг #9 — Фотки интерьера не нажимаются

**Корень проблемы (двойная):**

**A)** Когда API-слайды НЕ загружены (`useApi = false`) — `itemBuilder` в `interior_screen.dart:314` рендерит:
```dart
return ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Image.asset(assetPaths[i], fit: BoxFit.cover, ...),
);
```
Это **без** `PiligrimTap` — изображения не тапаются вообще.

**B)** Когда API-слайды загружены, но `caption` пустой — `InteriorPhotoViewer` открывается корректно. Это НЕ баг, viewer работает и без caption.

**Fix (основной — проблема A):** `InteriorPhotoViewer` принимает `List<InteriorSlide>`, а ассеты не являются `InteriorSlide`. Решение — создать лёгкий `_AssetPhotoViewer`:

```dart
// Новый приватный виджет/экран в interior_screen.dart или interior_photo_viewer.dart
class _AssetPhotoViewer extends StatefulWidget {
  const _AssetPhotoViewer({required this.paths, required this.initialIndex});
  final List<String> paths;
  final int initialIndex;
  // ...
  // PageView с Image.asset + PiligrimNavButton + счётчик
}
```

Обернуть asset-тайлы в `PiligrimTap` с вызовом `_AssetPhotoViewer`:

```dart
// interior_screen.dart:314
return PiligrimTap(
  onTap: () => Navigator.of(context).push(PiligrimPageRoute(
    builder: (_) => _AssetPhotoViewer(paths: assetPaths, initialIndex: i),
  )),
  borderRadius: BorderRadius.circular(12),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(assetPaths[i], fit: BoxFit.cover, cacheWidth: cacheW),
  ),
);
```

**Тест симулятор:** Интерьер → нажать на любое фото (hero-блок и сетка). Должен открываться полноэкранный viewer. Проверить как с API-слайдами, так и с fallback ассетами.

**Тест физ. Android:** Tap-area должна срабатывать с первого касания. Swipe-down для закрытия должен работать.

---

## Баг #10 — Общий стиль: итоговые несоответствия

После фиксов 1–9 — финальный чек:

| Элемент | Норма | Статус после фиксов |
|---|---|---|
| Кнопки назад | `PiligrimNavButton` везде | ✅ после #5 |
| Тег «Острое» | Единый стиль | ✅ после #7 |
| Разделители в карточках | `Container(height: 0.5, alpha: 0.10)` | ✅ после #2 |
| Карточки «Бронирований/Мероприятий/С нами» | Одна форма | ✅ после #6 |
| Карточки событий в Афише | Как на главной | ✅ после #8 |
| AppBar в admin-экранах | `PiligrimTap` в `leading` — допустимо (edit-контекст) | Оставить |
| `tour_webview_screen.dart` | `PiligrimNavButton` | ✅ входит в #5 |

### Финальный тест симулятор
Пройти весь golden path: Главная → Меню (видео + классика) → Интерьер (tap фото) → Афиша (tap события) → Профиль (бронирования, карточки статистики).

### Финальный тест физ. Android
Тот же путь. Особое внимание:
- Видео в меню не выходит за экран
- Tap-targets кнопок «назад» удобны
- Hairline-линии в карточках еле видны
- Карточки событий выглядят как на главной
- Фото интерьера открываются по тапу

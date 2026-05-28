# Проект: Cross-Platform iOS / Android паритет

**Статус:** Планирование  
**Стек:** Flutter  
**Scope:** Устранить все визуальные и поведенческие расхождения между iOS и Android (физические устройства + симуляторы). 10 тикетов, 6 блоков.  
**Принцип:** один тикет = одна изолированная задача. Ничего лишнего не трогать.

---

## Контекст

Расхождения найдены путём сравнения iOS симулятора и физического Android-устройства. Основные категории:

- **Android 15 edge-to-edge** — принудительный режим при `compileSdk = 35` не настроен в приложении
- **BackdropFilter** — на Android нестабилен (лаги при скролле, на ряде устройств отключён)
- **Клавиатура** — двойное сжатие на Android, светлая клавиатура на тёмном iOS-UI
- **ScrollPhysics** — три экрана жёстко ставят `ClampingScrollPhysics`, iOS теряет bounce
- **Hardcoded отступы** — магические числа вместо `MediaQuery`
- **Устаревшие API** — `MediaQuery.of().padding` вместо `MediaQuery.paddingOf()`

**Ключевые файлы:**
- `lib/main.dart` — SystemChrome, ScrollBehavior, RootShell
- `lib/screens/profile_screen.dart` — профиль, форма входа, GlassCard
- `lib/screens/phone_entry_screen.dart` — отдельный экран входа
- `lib/screens/home_screen.dart`, `menu_screen.dart`, `events_screen.dart`
- `lib/widgets/bottom_nav_bar.dart`, `lib/widgets/dish_video_card.dart`
- `android/app/src/main/res/values/styles.xml`

---

## Блок A — Системный UI и платформенная конфигурация

> Фундамент. Без этих фиксов всё остальное работает непредсказуемо на Android.

---

### TICKET-CP-01 — Edge-to-Edge, статус-бар, Android-тема

**Файлы:** `lib/main.dart`, `android/app/src/main/res/values/styles.xml`  
**Зависимости:** нет  
**Тест:** ручной — визуальная проверка на Android 15 и Android 12

**Проблема:** `compileSdk = 35` (Android 15) принудительно включает edge-to-edge. `main.dart` не вызывает `setEnabledSystemUIMode`. `styles.xml` → `NormalTheme` наследует `Theme.Light.NoTitleBar` → белая вспышка перед тёмным UI.

#### Технические шаги

- [ ] В `main()` до `setSystemUIOverlayStyle` добавить:
  ```dart
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  ```
- [ ] В `setSystemUIOverlayStyle` добавить два параметра:
  ```dart
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  ```
- [ ] В `android/app/src/main/res/values/styles.xml` изменить родителя `NormalTheme`:
  ```xml
  <!-- было -->
  <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
  <!-- стало -->
  <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
  ```
- [ ] Убедиться что `values-night/styles.xml` уже содержит `Theme.Black.NoTitleBar` (не менять)
- [ ] В `RootShell.build()` изменить `extendBody: false` → `extendBody: true` — при edge-to-edge тело должно расширяться за навбар, иначе снизу появляется тёмная полоса

---

### TICKET-CP-02 — PiligrimNavBar: корректный отступ при edge-to-edge

**Файл:** `lib/widgets/bottom_nav_bar.dart`  
**Зависимости:** TICKET-CP-01  
**Тест:** ручной — Android gesture nav + 3-кнопочная навигация

**Проблема:** `SafeArea(top: false, minimum: EdgeInsets.only(bottom: 5))` — hardcoded 5px недостаточен на некоторых Android-устройствах при edge-to-edge. Flutter сам корректно выставляет bottom inset через `SafeArea`.

#### Технические шаги

- [ ] Убрать `minimum: const EdgeInsets.only(bottom: 5)` из `SafeArea`, оставить только `top: false`:
  ```dart
  // было
  SafeArea(top: false, minimum: const EdgeInsets.only(bottom: 5), ...)
  // стало
  SafeArea(top: false, ...)
  ```
- [ ] Проверить высоту навбара визуально на Android с gesture nav (bottom inset ~0px) и 3-кнопочной (bottom inset ~24px)
- [ ] Проверить на iOS: iPhone с home indicator и без — навбар не должен обрезаться

---

## Блок B — BackdropFilter и стеклянный UI

> `BackdropFilter` на Android нестабилен: лагает при скролле, на ряде устройств отключён аппаратно.

---

### TICKET-CP-03 — Платформенный фолбек для `_ProfileGlassCard`

**Файл:** `lib/screens/profile_screen.dart` (класс `_ProfileGlassCard`, ~строка 1413)  
**Зависимости:** нет  
**Тест:** ручной — оба устройства, сравнить внешний вид карточек

**Проблема:** `BackdropFilter(filter: ImageFilter.blur(...))` применяется на всех платформах. На Android blur либо лагает при скролле, либо не рендерится — карточки выглядят плоскими или артефактными.

#### Технические шаги

- [ ] В начале файла добавить импорт:
  ```dart
  import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
  ```
- [ ] В методе `build` класса `_ProfileGlassCard` добавить переменную:
  ```dart
  final bool useBlur = defaultTargetPlatform == TargetPlatform.iOS;
  ```
- [ ] Для iOS-ветки (`useBlur == true`) — оставить существующий `ClipRRect` + `BackdropFilter` без изменений
- [ ] Для Android-ветки (`useBlur == false`) — вернуть `ClipRRect` с тем же `Container`, но без `BackdropFilter`. Увеличить непрозрачность заливки чтобы карточки читались без блюра:
  ```dart
  // вместо fillTop/fillBottom — умножить на 2.0 для Android
  final double androidFillTop = fillTop * 2.0;
  final double androidFillBottom = fillBottom * 2.0;
  ```
- [ ] Для `ProfileGlassVariant.integrated` — блюр не применялся и раньше, эта ветка не меняется
- [ ] Проверить все 4 варианта `ProfileGlassVariant` (panel, settings, stat, integrated) на Android

---

## Блок C — Клавиатура и Scaffold insets

> Разное поведение клавиатуры — главная причина "сломанного" UI при вводе на Android.

---

### TICKET-CP-04 — Убрать двойное сжатие в `_UnauthProfileView`

**Файл:** `lib/screens/profile_screen.dart` (класс `_UnauthProfileView`, ~строка 1515)  
**Зависимости:** нет  
**Тест:** ручной — физический Android, открыть клавиатуру в форме входа

**Проблема:** `resizeToAvoidBottomInset: true` + `SingleChildScrollView` с `padding: EdgeInsets.fromLTRB(28, 48, 28, bottom + 32)` — при открытии клавиатуры на Android Scaffold сжимает тело, `SingleChildScrollView` добавляет ещё один отступ. Форма скачет или клавиатура перекрывает поле.

#### Технические шаги

- [ ] Изменить `resizeToAvoidBottomInset: true` → `resizeToAvoidBottomInset: false`
- [ ] Заменить вычисление `bottom` в `build()`:
  ```dart
  // было
  final bottom = MediaQuery.paddingOf(context).bottom;
  // стало
  final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
  ```
- [ ] В `padding` `SingleChildScrollView` использовать `keyboardHeight`:
  ```dart
  // было
  padding: EdgeInsets.fromLTRB(28, 48, 28, bottom + 32),
  // стало
  padding: EdgeInsets.fromLTRB(28, 48, 28, keyboardHeight + 32),
  ```
- [ ] Проверить на Android: при открытии клавиатуры форма плавно скроллится, не прыгает
- [ ] Проверить на iOS: поведение не изменилось

---

### TICKET-CP-05 — `keyboardAppearance: Brightness.dark` в полях ввода

**Файлы:** `lib/screens/phone_entry_screen.dart`, `lib/screens/profile_screen.dart` (`_UnauthProfileView`)  
**Зависимости:** нет  
**Тест:** ручной — iOS симулятор, тапнуть на поле ввода телефона

**Проблема:** `TextField`/`TextFormField` без `keyboardAppearance`. На iOS системная клавиатура появляется белой поверх тёмного UI приложения.

#### Технические шаги

- [ ] `phone_entry_screen.dart` — в `TextFormField` для телефона (~строка 174) добавить:
  ```dart
  keyboardAppearance: Brightness.dark,
  ```
- [ ] `phone_entry_screen.dart` — в `TextFormField` для кода (~строка 205) добавить то же
- [ ] `profile_screen.dart` (`_UnauthProfileView`) — в `TextField` (~строка 1686) добавить:
  ```dart
  keyboardAppearance: Brightness.dark,
  ```
- [ ] Проверить на iOS симуляторе: клавиатура тёмная на обоих экранах

---

## Блок D — ScrollPhysics

> Три экрана жёстко задают `ClampingScrollPhysics`, что перебивает `_PlatformScrollBehavior` из `main.dart`. iOS теряет нативный bounce-скролл.

---

### TICKET-CP-06 — Убрать hardcoded `ClampingScrollPhysics` с трёх экранов

**Файлы:** `lib/screens/home_screen.dart` (~строка 131), `lib/screens/menu_screen.dart` (~строка 527), `lib/screens/profile_screen.dart` (~строка 151)  
**Зависимости:** нет  
**Тест:** ручной — iOS симулятор, проверить bounce при скролле до края

**Проблема:** `_PlatformScrollBehavior` в `main.dart` корректно даёт iOS `BouncingScrollPhysics`, но эти три экрана явно задают `ClampingScrollPhysics()` и перебивают его. На iPhone скролл ощущается как на Android.

#### Технические шаги

- [ ] `home_screen.dart` — найти `physics: const ClampingScrollPhysics()`, заменить на `physics: null` (унаследует от `_PlatformScrollBehavior`), либо удалить параметр полностью
- [ ] `menu_screen.dart` — то же самое
- [ ] `profile_screen.dart` — то же самое
- [ ] Убедиться что `MaterialApp.scrollBehavior: const _PlatformScrollBehavior()` в `main.dart` присутствует и не изменён
- [ ] Проверить на iOS: bounce на всех трёх экранах. Проверить на Android: clamping (без резины)

---

## Блок E — Отступы и SafeArea

> Hardcoded значения ломаются на устройствах с разными размерами экрана и разными режимами навигации.

---

### TICKET-CP-07 — Заменить hardcoded bottom padding 100px в профиле

**Файл:** `lib/screens/profile_screen.dart` (~строка 163)  
**Зависимости:** TICKET-CP-01  
**Тест:** ручной — Android gesture nav (bottom=0) и 3-кнопочная nav (bottom≈24px)

**Проблема:** `EdgeInsets.fromLTRB(20, 0, 20, 100)` — фиксированные 100px. На Android gesture nav последний элемент висит в пустоте, на устройствах с маленьким экраном — может обрезаться.

#### Технические шаги

- [ ] В методе `build` добавить вычисление:
  ```dart
  final bottomPad = MediaQuery.paddingOf(context).bottom + 32;
  ```
- [ ] Заменить hardcoded значение:
  ```dart
  // было
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
  // стало
  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
  ```
- [ ] Проверить визуально: последний элемент не обрезается ни на одной конфигурации

---

### TICKET-CP-08 — `MediaQuery.of(context).padding` → `MediaQuery.paddingOf()`

**Файл:** `lib/screens/events_screen.dart` (~строка 99) + grep по всему `lib/`  
**Зависимости:** нет  
**Тест:** `flutter analyze` — нет новых ошибок

**Проблема:** Устаревший `MediaQuery.of(context).padding` вызывает полную перерисовку виджета при любом изменении `MediaQueryData` (размер шрифта, яркость и т.д.). `paddingOf()` перестраивает только при изменении `padding`.

#### Технические шаги

- [ ] Запустить grep:
  ```bash
  grep -rn "MediaQuery.of(context).padding" lib/
  ```
- [ ] Для каждого найденного вхождения заменить:
  ```dart
  // было
  MediaQuery.of(context).padding.top
  // стало
  MediaQuery.paddingOf(context).top
  ```
- [ ] Аналогично заменить `MediaQuery.of(context).viewInsets` → `MediaQuery.viewInsetsOf(context)` если найдено
- [ ] Запустить `flutter analyze` — убедиться что нет ошибок

---

### TICKET-CP-09 — Адаптивная высота слайдера событий

**Файл:** `lib/screens/events_screen.dart` (~строка 614)  
**Зависимости:** нет  
**Тест:** ручной — iPhone SE (667px высота) и типичный Android (800px)

**Проблема:** `SizedBox(height: 194)` — фиксированная высота. На iPhone SE и бюджетных Android карточки выглядят сжато или слишком большими.

#### Технические шаги

- [ ] Заменить hardcoded высоту на адаптивную:
  ```dart
  // было
  SizedBox(height: 194, ...)
  // стало
  SizedBox(
    height: (MediaQuery.sizeOf(context).height * 0.24).clamp(160.0, 220.0),
    ...
  )
  ```
- [ ] Проверить на: iPhone SE (667h → 160px), iPhone 15 Pro (932h → 220px), Android 800h → ~192px

---

## Блок F — Typography

---

### TICKET-CP-10 — Text shadows не обрезаются на Android

**Файл:** `lib/widgets/dish_video_card.dart` (~строка 242)  
**Зависимости:** нет  
**Тест:** ручной — Android, карточки блюд в ленте

**Проблема:** `Text` с `shadows` внутри контейнера без overflow-padding. На Android тени за boundary виджета обрезаются клипом родителя.

#### Технические шаги

- [ ] Найти все `Text(...)` со `shadows` в `dish_video_card.dart`
- [ ] Обернуть каждый в `Padding(padding: const EdgeInsets.all(4))` или добавить `padding` к ближайшему родительскому контейнеру
- [ ] Убедиться что `overflow: TextOverflow.ellipsis` сохранён (если был)
- [ ] Проверить на Android: тени видны полностью

---

## Порядок реализации

```
CP-01 ──► CP-02 (edge-to-edge фундамент)
CP-03           (BackdropFilter — независим)
CP-04           (клавиатура — независима)
CP-05           (keyboardAppearance — независима)
CP-06           (ScrollPhysics — независим)
CP-07 ──► CP-01 (bottom padding — после edge-to-edge)
CP-08           (MediaQuery API — независим)
CP-09           (адаптивная высота — независима)
CP-10           (text shadows — независим)
```

**Обязательная последовательность:** CP-01 → CP-02 первыми.  
**Остальные:** можно параллельно после CP-01.

---

## Оценка времени

| Тикет | Файлы | Время |
|---|---|---|
| CP-01: Edge-to-Edge + Android тема | main.dart, styles.xml | 30 мин |
| CP-02: NavBar отступ | bottom_nav_bar.dart | 15 мин |
| CP-03: BackdropFilter фолбек | profile_screen.dart | 45 мин |
| CP-04: Двойное сжатие клавиатуры | profile_screen.dart | 20 мин |
| CP-05: keyboardAppearance | phone_entry_screen.dart, profile_screen.dart | 10 мин |
| CP-06: ScrollPhysics | home, menu, profile | 15 мин |
| CP-07: Bottom padding 100px | profile_screen.dart | 10 мин |
| CP-08: MediaQuery.paddingOf() | events_screen.dart + grep | 15 мин |
| CP-09: Высота слайдера | events_screen.dart | 10 мин |
| CP-10: Text shadows | dish_video_card.dart | 15 мин |
| **Итого** | **10 тикетов** | **~3 часа** |

---

## Риски

| Риск | Вероятность | Митигация |
|---|---|---|
| `extendBody: true` сломает отступ контента на старых Android (< API 30) | Средняя | `SafeArea` в каждом экране компенсирует; навбар с `SafeArea(top: false)` защищает снизу |
| `BackdropFilter` отключён не только на Android — может быть и на слабых iOS | Низкая | Проверить на iPhone SE (A9) — если лаги, расширить условие |
| `physics: null` на `home_screen.dart` — `PageView` внутри может перехватить жест | Низкая | Проверить что `PageView` (если есть) использует свою физику отдельно |
| `MediaQuery.viewInsetsOf` не обновляется когда клавиатура скрывается постепенно | Низкая | Является стандартным поведением Flutter — viewInsets обновляется покадрово |
| `(height * 0.24).clamp(160, 220)` — на iPad размер будет 220px, маловато | Низкая | iPad не в приоритете (portrait-only); при необходимости clamp расширить |

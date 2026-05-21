# PILIGRIM — Design Improvement Plan

## Status legend: ✅ Done | 🔄 In Progress | ⬜ Pending

---

## ФАЗА 0 — Фундамент ✅ DONE
- ✅ Добавить `PiligrimColors.earthSurface`, `navBarBase`, `navBarTop`, `navBarRim` в theme.dart
- ✅ Добавить tag colors: `tagSpicy`, `tagVegetarian`, `tagAlcohol`, `tagHalal` в theme.dart
- ✅ Добавить `PiligrimSpacing` (xs/sm/md/lg/xl/xxl/section/cardGap) в theme.dart
- ✅ Добавить `PiligrimRadius` (sm/md/card/lg + BorderRadius variants) в theme.dart
- ✅ `home_screen.dart`: `Color(0xFF1E1B19)` → `PiligrimColors.earthSurface`
- ✅ `bottom_nav_bar.dart`: все хардкод цвета → theme constants
- ✅ `profile_data.dart`: `Color(0xFFC4956A)` × 3 → `PiligrimColors.steppe`
- ✅ `menu_data.dart`: tag colors → `PiligrimColors.tag*`

---

## ФАЗА 1 — Bottom Navigation Bar ✅ DONE
- ✅ Активный таб: dot → horizontal line 1.5px под иконкой + water glow (boxShadow)
- ✅ Иконки: 22/18 → 24/20 через AnimatedScale(_inactiveScale = 20/24)
- ✅ Анимация: 280ms → 350ms + Curves.easeInOutCubic (иконка + линия + текст)
- ✅ Label letterSpacing: active 0.6, inactive 0.9
- ✅ AnimatedDefaultTextStyle для плавного перехода цвета/letterSpacing
- ✅ Glow на активной иконке: water @ 22% alpha, blurRadius 14
- ✅ Shadow нав бара: чуть мягче (0x18 alpha, -3 offset)

---

## ФАЗА 2 — Home Screen ✅ DONE
- ✅ HomeHeroSection: placeholder Color(0xFF1E1B19) → PiligrimColors.earthSurface
- ✅ HomeHeroIntroBlock: gradient hairline-разделитель (fade-in), subtitle letterSpacing 0.35
- ✅ EmberCta: height 50→56, borderRadius 8→10, rim-highlight 0.75px, shadow глубже
- ✅ HomeTotemPathRow: выбранная карточка ярче (border 0.22→0.38, bg 0.03→0.055, shadow 0.10→0.14)
- ✅ HomeEventBlock: card-контейнер (earthDeep @ 55%, border, shadow), steppe left-accent-line, дата steppe@0.95, теги water@0.75, "Все события" water@0.80
- ✅ HomeStatusLine: закрыто → fruit@0.55 dot + fruit@0.65 текст (было sky@0.2/0.3)

---

## ФАЗА 3 — Menu Screen ✅ DONE

### 3.1 Header «МЕНЮ»
- ✅ Тонкая steppe→transparent hairline (56×1) под caps-заголовком «МЕНЮ» — единый штрих с section headers

### 3.2 Mode Switcher «Путь / Свиток»
- ✅ Sliding water pill-indicator: `AnimatedAlign` 280ms / `easeOutCubic`
- ✅ Активная вкладка — water-цвет иконки/текста + glow (water @ 0.18, blur 12, spread 0.5)
- ✅ Неактивная — sky @ 0.45, w300, letterSpacing 0.4
- ✅ Полный pill (radius 18), height 36, ширина дорожки 184
- ✅ `AnimatedDefaultTextStyle` 220ms для плавного перехода weight/letterSpacing

### 3.3 SearchBar
- ✅ water-иконка `luk.svg` (вместо steppe)
- ✅ Clear-кнопка (×) появляется при тексте — `PiligrimTap` + `AnimatedSwitcher` fade+scale 180ms
- ✅ Focus-glow: water border @ 0.55 + boxShadow water @ 0.12 blur 14, 220ms
- ✅ Cursor color → water
- ✅ borderRadius 12 — сохранён

### 3.4 Category Tabs (горизонтальный скролл)
- ✅ Полный pill (radius 24), height 40
- ✅ Активная: steppe @ 0.18 + steppe border @ 0.6 + heading w700 + letterSpacing 0.6
- ✅ Неактивная: earth @ 0.4 + divider border + sky @ 0.5 w300
- ✅ `AnimatedDefaultTextStyle` 220ms — плавная смена веса

### 3.5 Filter Chips (теги)
- ✅ borderRadius 6 → 18 (полный pill)
- ✅ Высота 38 → 32, выровненный padding (h14)
- ✅ Активные chips — заливка @ 0.22, border @ 0.55, тег-цвет из реестра
- ✅ `AnimatedContainer` 200ms + `AnimatedDefaultTextStyle` на letterSpacing/weight

### 3.6 Группировка по категориям в классическом меню
- ✅ При `activeCategoryId == null`, пустом поиске и без тегов → группировка
- ✅ Section header: caps name (steppe @ 0.82, letterSpacing 2.5, fontSize 11) + горизонтальная steppe→transparent gradient hairline
- ✅ При фильтрации (категория/поиск/тег) — плоский список без секций
- ✅ Категории сортируются по `order` из `ApiCategory`; неизвестные id уходят в конец
- ✅ Section header — fadeIn + slideY 450ms easeOut

### 3.7 ClassicDishCard
- ✅ Pill-badge категории сверху-слева на изображении (caps, sky @ 0.9, backdrop earthDeep @ 0.62 + water border @ 0.38)
- ✅ Многоступенчатый bottom gradient — 4 stops (0 / 0.45 / 0.82 / 1.0)
- ✅ Цена pill: padding h12 v6, steppe border @ 0.55 + boxShadow @ 0.25, font 14 w700
- ✅ Heading-название (`PiligrimTextStyles.heading`) — сохранено
- ✅ steppe-цена — сохранено

### 3.8 DishVideoCard (видео-лента)
- ✅ Pill-badge категории под status bar (top+60, left 20): sky text @ 0.92, water border @ 0.4, backdrop black @ 0.55, fadeIn 500ms (delay 300ms)
- ✅ Многоступенчатый bottom-gradient — 5 stops, высота 360 (без визуальной «полосы»)
- ✅ Имя категории берётся из `MenuProvider.categories` через `context.select` — без новых полей в модели
- ✅ Mute-button и swipe-hint — без изменений

### 3.9 Empty / Loading states
- ✅ Empty: тотем `spiral.svg` 44px + caption steppe @ 0.45 + подсказка «попробуйте сменить фильтр или поиск» (sky @ 0.3)
- ✅ Тотем — медленный breathing scale 1.0 → 1.04 (2600ms reverse)
- ✅ fadeIn 500ms всего блока
- ✅ steppe spinner — сохранён

### Проверки
- ✅ `flutter analyze lib/screens/menu_screen.dart lib/widgets/dish_video_card.dart` — `No issues found`
- ✅ `flutter test test/navigation_test.dart` — 4/4
- ✅ `flutter test test/providers/menu_provider_test.dart` — All passed
- ℹ Pre-existing failures в `menu_repository_test`, `booking_screen_test`, `profile_screen_test` не задеты Фазой 3 (проверено `git stash`)

---

## ФАЗА 4 — Events Screen ✅ DONE

### 4.1 Header «АФИША»
- ✅ Унификация с MenuScreen: `_AfichaTitleBlock` — тотем `tree_totem` (18px steppe @0.6) + caps «АФИША» (steppe @0.78, ls 3.0, fs 10) + steppe→transparent hairline (56×1)
- ✅ Подзаголовок «Лента мероприятий и вестей заведения» — sky @0.45, fs 11.5, ls 0.4

### 4.2 Tab switcher «Афиша / Новости»
- ✅ Sliding water pill-indicator (как в MenuScreen ModeSwitcher): `AnimatedAlign` 280ms / `easeOutCubic`
- ✅ Активная вкладка — water-цвет иконки/текста + glow (water @0.18, blur 14, spread 0.5)
- ✅ Неактивная — sky @0.45, w300, letterSpacing 0.4
- ✅ Полный pill (radius 22), height 44, full width (через `LayoutBuilder`)
- ✅ Иконки: `tree_totem` (Афиша) / `spiral` (Новости) 14×14
- ✅ `AnimatedDefaultTextStyle` 220ms — плавный переход weight/letterSpacing

### 4.3 Hero slider («Кадры пространства»)
- ✅ Chip-badge: sky @0.92 caps text, water border @0.4, backdrop earthDeep @0.62 (как dish-badge)
- ✅ Progress indicator: `_HeroDotsIndicator` — активная точка water @0.85 (22×4 pill с glow), неактивные sky @0.18 (6×4)
- ✅ Caption: «Кадр $idx из $total» — micro-style (sky @0.40, ls 1.4, fs 10.5)
- ✅ CTA внутри слайда — caps + letterSpacing 1.0 + chevron «→»

### 4.4 Section headers «БЛИЖАЙШИЕ СОБЫТИЯ» / «НОВОСТИ»
- ✅ `_AfichaSectionHeader` — caps (steppe @0.82, ls 2.5, fs 11) + steppe→transparent hairline gradient (по аналогии с `_CategorySectionHeader` из Menu)
- ✅ fadeIn + slideY 450ms easeOut

### 4.5 EventListCard (предстоящее)
- ✅ Date water-pill на изображении (top): «23 МАЙ · 19:00», water border @0.4, backdrop earthDeep @0.7, sky @0.92 text
- ✅ Format badge (bottom): «ОТКРЫТОЕ» (water @0.45 border + dot) / «ЗАКРЫТОЕ» (steppe @0.55 border + dot) — micro (sky @0.85, ls 0.8, fs 8.5)
- ✅ Steppe-left-accent-line (2.5px width × full height, gradient steppe @0.55 → steppe @0.0)
- ✅ Многоступенчатый gradient на обложке (4 stops)
- ✅ Title — heading w700 sky, fs 16.5, height 1.25
- ✅ Дата — water @0.95, fs 12, letterSpacing 0.3
- ✅ Стоимость — steppe @0.78, fs 11.5 со steppe-dot префиксом 4×4
- ✅ Описание — sky @0.62, fs 13, height 1.45, maxLines 2
- ✅ Boxshadow @0.18 для глубины
- ✅ FadeIn + SlideY волной 60ms на карточку

### 4.6 Archive header (аккордеон)
- ✅ Wheel_totem 22px → water @0.55
- ✅ Caption «$count мероприятий · фотоотчёты по метке» — sky @0.45, fs 11
- ✅ Chevron: `AnimatedRotation` 260ms easeOutCubic (плюс → крест)
- ✅ Архив раскрывается через `AnimatedSize` 320ms easeOutCubic
- ✅ Тонкая steppe→transparent hairline (40×1) внутри заголовка
- ✅ Раскрытое состояние: water border @0.28 + earthDeep @0.55

### 4.7 PastEventCard
- ✅ Photo-report hint chip — `_PhotoReportChip` (water @0.85, ls 0.8, fs 9, caps), показывается при `hasPhotoReport`
- ✅ Title — sky @0.78, w700 fs 14, height 1.3
- ✅ Date — sky @0.38, fs 11.5 (микро-вторичная информация)
- ✅ Matte-вуаль earth @0.22 поверх обложки — атмосфера «архивности»

### 4.8 NewsCard
- ✅ Steppe-accent line по левому краю (1.5px, gradient steppe @0.55 → steppe @0.0)
- ✅ Title — heading w700 sky, fs 17, со steppe-dot префиксом 4×4
- ✅ Date — water @0.85, fs 12 + mini hairline-divider (sky @0.10, 20×1)
- ✅ Body — sky @0.88, fs 14, height 1.6
- ✅ Изображение — borderRadius 10 + bottom gradient overlay для глубины
- ✅ Boxshadow @0.16

### 4.9 Empty / Loading states
- ✅ `_AfichaEmpty` — тотем 44px steppe @0.22 (breathing reverse 2600ms) + caption + sky @0.30 hint
- ✅ Events empty: `tree_totem` + «Пока нет ближайших событий» + «Новые маршруты появятся скоро»
- ✅ News empty: `spiral.svg` + «Пока нет новостей» + «Загляните позже — ритм заведения меняется»
- ✅ Loading skeleton: `_EventsLoadingSkeleton` / `_NewsLoadingSkeleton` — 2 breathing placeholder-карточки с stagger 120ms

### 4.10 Event detail screen (event_detail_screen.dart)
- ✅ MetaChip: steppe border @0.55, backdrop earthDeep @0.55, steppe glow-dot 5×5 перед текстом, fs 12 sky @0.92 w700
- ✅ CTA `_EventSignupCta` — water → waterMuted gradient, rim-highlight 0.75px (sky @0.22), shadow @0.28 + water glow @0.25, height 54, radius 12, letterSpacing 1.6, caps
- ✅ Дата мероприятия — water glow-dot 5×5 + text water fs 14
- ✅ Price-line — steppe dot 4×4 префикс + текст @0.85, ls 0.3
- ✅ Steppe→transparent hairline (56×1) перед описанием

### 4.11 Доп. улучшения (вне исходного плана)
- ✅ Bonus: офлайн-режим — `_OfflineHint` со steppe glow-dot вместо голой строки
- ✅ Bonus: skeleton-loading вместо одинокого spinner'а
- ✅ Bonus: stagger fadeIn+slideY на карточках событий и новостей (60ms на индекс)

### Проверки
- ✅ `flutter analyze lib/screens/events_screen.dart lib/screens/event_detail_screen.dart` — `No issues found! (ran in 2.5s)`
- ✅ `flutter test test/navigation_test.dart` — 4/4 passed
- ✅ `flutter test test/widgets/event_*.dart` — 5/5 passed

---

## ФАЗА 5 — Interior Screen ⬜ PENDING
- [ ] Zone filter: горизонтальный скролл, плавнее
- [ ] Галерея: borderRadius 8, gap 3px
- [ ] Кнопка аудио: floating pill
- [ ] Photo viewer: счётчик micro-style

---

## ФАЗА 6 — Profile Screen ⬜ PENDING
- [ ] Header: title-style имя, caption-телефон
- [ ] Секции: spacing 32→40px
- [ ] Toggles: кастомный pill-toggle water/steppe
- [ ] Контактные карточки: steppe-иконки, PiligrimTap
- [ ] Booking status badges: water/fruit pills
- [ ] Кнопка выхода: fruit-color текст

---

## ФАЗА 7 — Booking Flow ⬜ PENDING
- [ ] Input fields: brand InputDecoration, borderRadius 10
- [ ] Zone picker: 3 карточки с иконками
- [ ] Date/time: кастомный picker
- [ ] Stepper гостей: − / + кнопки
- [ ] EmberCta: chevron-right icon
- [ ] Экран успеха: animated totem + поздравление

---

## ФАЗА 8 — Auth Flow ⬜ PENDING
- [ ] OTP input: 6 отдельных полей
- [ ] PhoneEntry: EmberCta стиль
- [ ] Onboarding: tagline бренда

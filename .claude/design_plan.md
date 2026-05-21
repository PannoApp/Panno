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

## ФАЗА 3 — Menu Screen ⬜ PENDING
- [ ] Режим-переключатель: pill-switcher с water-акцентом
- [ ] DishVideoCard: gradient overlay улучшить, pill-badge категории
- [ ] Tag badges: перенести в theme (done в ф.0), округлить borderRadius
- [ ] Классическое меню: steppe-линия у заголовков категорий
- [ ] Поиск: borderRadius 12, water иконка
- [ ] Карточка блюда: steppe-цена, heading-название

---

## ФАЗА 4 — Events Screen ⬜ PENDING
- [ ] Tab switcher: pill с water-active
- [ ] Карточка события: date badge (water-pill)
- [ ] Кнопка «Записаться»: outline water
- [ ] Карточка новостей: steppe-заголовок
- [ ] Пустые состояния: totem + текст

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

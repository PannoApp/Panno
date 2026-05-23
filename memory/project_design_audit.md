---
name: project-design-audit
description: Full brand/TZ audit of PILIGRIM app — prioritized improvement plan, May 2026
metadata:
  type: project
---

Full audit performed 2026-05-23. Compared app against brand/piligrim_design_spec.md and brand/TZ Piligrim App.md.

**Why:** User wants premium-level design quality, all screens must match brand atmosphere.

**How to apply:** Follow this plan task by task in order. Mark [x] when done. Never skip ahead.

---

## STATUS: IN PROGRESS — Tasks 1–6 DONE ✅

---

## 🔴 PRIORITY 1 — Critical (brand atmosphere broken)

### Task 1: Onboarding Screen — atmospheric redesign
**File:** `lib/screens/onboarding_screen.dart`
**Status:** [x] DONE ✅ 2026-05-23

Current state: Plain dark screen with two text fields (name/last name). No background, no totem, no journey narrative.

Brand spec §7: "Онбординг — Вертикальный скролл, звезда 'ведёт' вниз по линии пути"
TZ §9: Onboarding = "Начало пути (обряд инициации)"

What to do:
- Add `PiligrimBackground(cinematic: true)` behind content
- Add animated star totem at top (reuse splash screen logic)
- Add vertical path line between star and form (same as splash)
- Style text fields with brand-consistent decoration (dark fill, steppe border, sky text)
- "Добро пожаловать, Герой" — keep, it's correct
- "Начать путь" button → use `EmberCta` widget (currently may be a plain ElevatedButton)
- Loading state: star pulse animation, not `CircularProgressIndicator`
- Fade-in animations on each element (staggered, 200–400ms per brand spec)

---

### Task 2: Menu Screen — branded loading state
**File:** `lib/screens/menu_screen.dart:41`
**Status:** [x] DONE ✅ 2026-05-23

Current state:
```dart
if (!menuProvider.loaded) return const SizedBox.shrink();
```
Users see blank screen while menu loads.

What to do:
- Replace with a shimmer skeleton for the active mode (feed or classic)
- Use existing `PiligrimShimmer` widget from `lib/widgets/piligrim_shimmer.dart`
- For video feed mode: show 1 full-screen dark shimmer card with piligrim totem centered
- For classic mode: show 2–3 stacked card shimmer skeletons

---

## 🟡 PRIORITY 2 — Medium (tone and atmosphere)

### Task 3: Events Screen — "вестей" archaic word
**File:** `lib/screens/events_screen.dart:76`
**Status:** [x] DONE ✅ 2026-05-23

Fix:
```dart
// Before:
'Лента мероприятий и вестей заведения'
// After:
'Лента мероприятий и новостей'
```

---

### Task 4: Events Screen — remove "Кадр X из Y" counter
**File:** `lib/screens/events_screen.dart`
**Status:** [x] DONE ✅ 2026-05-23

The text "Кадр 2 из 3" under the hero carousel is too functional/technical.
Remove the text counter entirely. Keep only styled dots indicator.
Active dot: pill shape, steppe color. Inactive: circle, divider color.

---

### Task 5: Events Screen — remove/restyle "Офлайн-режим" indicator
**File:** `lib/screens/events_screen.dart`
**Status:** [x] DONE ✅ 2026-05-23 — replaced with tiny stealthy dot + "демо" micro-text

"Офлайн-режим · показаны демо-события" breaks immersion.
Options (pick most atmospheric):
- Remove entirely (silently show demo data)
- Or replace with a single tiny dot indicator (no text) in steppe color

---

### Task 6: Replace all `CircularProgressIndicator` with `PiligrimLoader`
**Files:** Multiple screens
**Status:** [x] DONE ✅ 2026-05-23 — created lib/widgets/piligrim_loader.dart, replaced in menu/booking/history/interior/tour_webview

Brand spec §7: "Загрузка — Анимация звезды-тотема, пульсация"

Create `lib/widgets/piligrim_loader.dart` — pulsing star totem widget.
Then replace all occurrences:
- `lib/screens/menu_screen.dart:318` — classic menu infinite scroll loader
- `lib/screens/menu_screen.dart:541` — category loading
- `lib/screens/booking_screen.dart:483` — booking submit
- `lib/screens/booking_history_screen.dart:99` — history loading
- `lib/screens/onboarding_screen.dart:122` — save profile loading
- `lib/screens/interior_screen.dart:244` — interior photos loading
- `lib/screens/tour_webview_screen.dart:71` — webview loading

---

### Task 7: Replace Material `Icons.*` with totem/custom icons where possible
**Files:** Multiple screens
**Status:** [x] DONE ✅ 2026-05-23 — replaced all 8 occurrences with text symbols (×, →, ↗) or SVG splash_path for back buttons

Occurrences to address:
- `interior_screen.dart:489` — `Icons.open_in_full_rounded` (expand photo) → keep or use `↗` text
- `interior_screen.dart:704` — `Icons.arrow_forward_ios_rounded` in tour button → `→` or steppe arrow
- `menu_screen.dart:1039` — `Icons.close_rounded` (search clear) → `×` text or styled X
- `booking_screen.dart:239` — `Icons.arrow_back_ios_new_rounded` → text `←` or piligrim back button
- `booking_screen.dart:426` — `Icons.info_outline_rounded` — can keep (info icon, not nav)
- `profile_screen.dart:1282` — `Icons.logout_rounded` → totem icon or simple text
- `phone_entry_screen.dart:110` — `Icons.arrow_back_ios_new_rounded` → consistent back button
- `tour_webview_screen.dart:60` — `Icons.close` → text `×` styled
- `tour_webview_screen.dart:85` — `Icons.wifi_off_rounded` → can keep (wifi off = universal)
- `splash_screen.dart:501` — `Icons.close` in update banner → `×` text

---

### Task 8: Booking Success Screen — more poetic text
**File:** `lib/screens/booking_success_screen.dart`
**Status:** [ ] TODO

Current: bullet list of push notification descriptions (technical).
Brand spec §9: "Завершение = Завершение / Вознаграждение" — should feel ceremonial.

What to do:
- Main message: "Ваш путь принят. Проводники PILIGRIM свяжутся с вами." (or similar)
- Keep info about pushes but as smaller secondary text, not bullet list
- Add star totem pulse animation on success screen
- Use water color for the confirmation circle border (already done ✅)

---

## ⚪ PRIORITY 3 — Polish (fine details)

### Task 9: Home hero — branded page indicator dots
**File:** `lib/widgets/home_hero_section.dart`
**Status:** [ ] TODO

Replace standard PageView dots with brand-styled indicator:
- Active: pill shape (~20px wide, 2px tall), steppe color `#C4956A`
- Inactive: circle (4px), divider color `rgba(242,237,228,0.3)`
- Smooth animated transition between states

---

### Task 10: Events archive — more atmospheric copy
**File:** `lib/screens/events_screen.dart`
**Status:** [ ] TODO

"5 мероприятий · фотоотчёты по метке" → more atmospheric.
Options:
- "5 вечеров · фотоистория" 
- Or just show count without "по метке"

---

### Task 11: Profile — rules empty state fallback
**File:** `lib/screens/profile_screen.dart`
**Status:** [ ] TODO

When `coreInfo.visitRules` is null/empty, `_RulesCard(rules: null)` must show a graceful branded placeholder, not an empty/broken card.

---

## 📋 BACKLOG (future features from TZ)

### Task 12: Interior photo tap-hints (TZ §4.3)
**File:** `lib/screens/interior_screen.dart`
**Status:** [ ] BACKLOG

TZ §4.3: "тап на элемент интерьера → короткое описание (например, «Стена облицована саксаулом…»)"
Not implemented. Requires backend support for hints data + overlay UI.

---

## DESIGN PRINCIPLES TO FOLLOW

- Never use Material icons where totem SVG or text alternative works
- Every loading state = totem pulse animation
- Every empty state = atmospheric copy + totem icon (steppe color, 18-28% opacity)
- Animations: 200–400ms, easeOut/easeInOutCubic
- Text tone: поэтичный, современный, без архаизмов
- Colors: strictly from PiligrimColors — no hardcoded hex elsewhere
- Brand name: always PILIGRIM or Piligrim in text, never piligrim

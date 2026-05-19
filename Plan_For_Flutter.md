# PILIGRIM — Flutter App: План исправлений и доработок

> Документ описывает актуальные задачи по устранению расхождений Flutter-приложения с ТЗ и бэкендом.
> Разработчики: **Шерхан** (слой данных — модели, провайдеры, репозитории, сервисы) и **Архат** (слой UI — экраны, виджеты, очистка интерфейса).
>
> Бэкенд соответствует ТЗ и является источником истины. Все расхождения — на стороне Flutter.

---

## Контекст

Приложение имеет полностью готовый UI и интеграцию с API (8 экранов, 25+ виджетов, провайдеры, репозитории, сервисы). В ходе аудита выявлены критические баги парсинга данных, несуществующий по ТЗ функционал в UI, и хардкоженные данные вместо значений из API.

**Принцип разделения:**
- Шерхан — слой данных (модели, провайдеры, репозитории, сервисы, авторизация)
- Архат — слой UI (экраны, виджеты, очистка, навигация)

**Параллельный старт:** оба начинают с первого дня. Архат разблокируется для Блока А-3 после того, как Шерхан закрыл Блок Ш-2.

---

## Архитектура (зафиксирована)

| Решение | Выбор |
|---|---|
| HTTP client | `dio ^5.7` — JWT-интерцептор, retry |
| Хранение токенов | `flutter_secure_storage ^9.2` |
| State management | `provider ^6.1` + `ChangeNotifier` |
| Изображения из API | `cached_network_image ^3.4` |
| Видео | `video_player ^2.9` |
| Push | `firebase_core + firebase_messaging` |
| UUID | `uuid ^4.5` — Idempotency-Key |
| Тестирование | `mocktail ^1.0` |

**Auth Guard Pattern (используется везде):**
```dart
if (!context.read<AuthProvider>().isLoggedIn) {
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => PhoneEntryScreen(),
  ));
  if (!context.read<AuthProvider>().isLoggedIn) return;
}
```

**CoreInfo singleton** загружается при старте через `CoreInfoProvider()..load()` и используется на всех экранах.

---

## Зависимости между блоками

```
Ш-1 ──────────────────────────────────── независимый, стартует сразу
Ш-2 ──── разблокирует → А-3 (карта, ссылки, депозит)
Ш-3 ──── разблокирует → А-4 (уведомления, статистика, онбординг)
А-1 ──────────────────────────────────── независимый, стартует сразу
А-2 ──────────────────────────────────── независимый, стартует сразу
```

---

---

# ШЕРХАН — Слой данных

---

## Ш-1 | Критические баги парсинга данных

**Ветка:** `fix/data-parsing-bugs`
**Зависимости:** нет — стартует сразу

---

### Ш-1.1 | Видеополе блюда

**Файл:** `lib/data/models/api_dish.dart:64`

**Проблема:** Backend возвращает два поля: `video` (исходный файл) и `video_url` (обработанное H.264 720×1280, готово к стримингу). Flutter читает `video` — видео либо не воспроизводится, либо воспроизводится нестабильно. Рвётся вся видео-лента.

**Изменение:**
```dart
// БЫЛО:
videoUrl: parseStringOrNull(json['video']),

// СТАЛО:
videoUrl: parseStringOrNull(json['video_url'] ?? json['video']),
```
Фолбэк на `json['video']` — защита на случай если сервер вернёт старый формат.

**Тесты** (`test/data/models/api_dish_test.dart`):
- JSON с `video_url` → `videoUrl` не null
- JSON только с `video` (без `video_url`) → `videoUrl` читается из `video`
- JSON без обоих полей → `videoUrl == null`

---

### Ш-1.2 | Формат времени при бронировании

**Файл:** `lib/screens/booking_screen.dart:166-170`

**Проблема:** Django `TimeField` требует `"HH:MM:SS"`. Flutter отправляет `"HH:MM"` → бронирование падает с 400. Пользователь при этом выбирает время в формате HH:MM — так и должно оставаться в UI.

**Изменение:** разделить display-строку и API-строку.

```dart
// Строка для отображения пользователю — без изменений:
String get _timeLabel {
  final h = _visitTime.hour.toString().padLeft(2, '0');
  final m = _visitTime.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// Строка для отправки на API — добавить:
String get _timeForApi {
  final h = _visitTime.hour.toString().padLeft(2, '0');
  final m = _visitTime.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}
```

В методе `_submit` заменить `_timeLabel` на `_timeForApi` при формировании тела запроса.

**Тесты** (`test/screens/booking_screen_test.dart`):
- `TimeOfDay(hour: 9, minute: 5)` → `_timeForApi == '09:05:00'`
- `TimeOfDay(hour: 23, minute: 59)` → `_timeForApi == '23:59:00'`
- `_timeLabel` по-прежнему возвращает `'HH:MM'` (без секунд)

---

### Ш-1.3 | Парсинг цены события

**Файл:** `lib/data/models/api_event.dart:56-57`

**Проблема:** Два бага одновременно:
1. Backend возвращает поле `"price"`, не `"price_from"`. Приоритет поиска в коде неверный.
2. Backend возвращает `"3500.00"` (строка-десятичная). `int.tryParse("3500.00")` → `null`. Цена всегда теряется.

**Изменение:**

```dart
// Добавить вспомогательную функцию в файл:
int? _parseDecimalPrice(dynamic v) {
  if (v == null) return null;
  return (double.tryParse('$v') ?? 0.0).round();
}

// БЫЛО:
priceFrom: parseIntOrNull(
  json['price_from'] ?? json['priceFrom'] ?? json['price'],
),

// СТАЛО:
priceFrom: _parseDecimalPrice(json['price'] ?? json['price_from']),
```

**Тесты** (`test/data/models/api_event_test.dart`):
- `{"price": "3500.00"}` → `priceFrom == 3500`
- `{"price": "0.00"}` → `priceFrom == 0`
- `{"price": null}` → `priceFrom == null`
- `{"price": 3500}` (int) → `priceFrom == 3500` (защита от int-ответа)
- JSON без поля `price` → `priceFrom == null`

---

## Ш-2 | Расширение модели CoreInfo

**Ветка:** `fix/core-info-missing-fields`
**Зависимости:** нет — стартует сразу
> ⚠️ Этот блок блокирует А-3. Приоритет — выполнить до А-3.

---

### Ш-2.1 | Добавить 6 полей в CoreInfo

**Файл:** `lib/data/models/core_info.dart`

**Проблема:** Backend на `GET /api/v1/core/info/` возвращает поля, которых нет в модели. Карта, обратная связь и пользовательское соглашение используют захардкоженные данные вместо API.

**Изменение — добавить в конструктор и класс:**

```dart
// Новые nullable-поля:
final String? twogisLink;
final String? googleMapsLink;
final String? yandexMapsLink;
final String? feedbackUrl;
final String? termsOfService;
final String? tourLink; // парсим, UI не строим — ресторан ещё не открыт
```

**Изменение — в `fromJson()`:**

```dart
twogisLink: parseStringOrNull(json['twogis_link'] ?? json['twogisLink']),
googleMapsLink: parseStringOrNull(json['google_maps_link'] ?? json['googleMapsLink']),
yandexMapsLink: parseStringOrNull(json['yandex_maps_link'] ?? json['yandexMapsLink']),
feedbackUrl: parseStringOrNull(json['feedback_url'] ?? json['feedbackUrl']),
termsOfService: parseStringOrNull(json['terms_of_service'] ?? json['termsOfService']),
tourLink: parseStringOrNull(json['tour_link'] ?? json['tourLink']),
```

**Изменение — в `toJson()`:** добавить шесть nullable-записей через `if (field != null)`.

**Тесты** (`test/data/models/core_info_test.dart`):
- JSON со всеми шестью полями → все поля не null
- JSON без этих полей → все поля null
- Существующие поля не нарушены

**Документация:** обновить описание `CoreInfo` в этом файле (раздел «Архитектура CoreInfo»).

---

## Ш-3 | UserProfile, Auth flow, статистика профиля

**Ветка:** `fix/auth-profile-data`
**Зависимости:** нет — стартует сразу
> Блок А-4 зависит от Ш-3.

---

### Ш-3.1 | Добавить поля в UserProfile

**Файл:** `lib/data/models/user_profile.dart`

**Проблема:** Модель не содержит `notifications_enabled` (глобальный мастер-переключатель уведомлений) и `date_joined` (нужен для вычисления `journeyStartLabel`).

**Изменение — добавить поля:**

```dart
final bool notificationsEnabled;
final DateTime? dateJoined;
```

**В `fromJson()`:**
```dart
notificationsEnabled: parseBool(
  json['notifications_enabled'] ?? json['notificationsEnabled'],
  defaultValue: true,
),
dateJoined: json['date_joined'] != null
    ? DateTime.tryParse(json['date_joined'] as String)
    : null,
```

**В `copyWith()`:** добавить параметры `notificationsEnabled` и `dateJoined`.

**В `toJson()`:** добавить `'notifications_enabled': notificationsEnabled`.

**Тесты** (`test/data/models/user_profile_test.dart`):
- `{"notifications_enabled": false}` → `notificationsEnabled == false`
- поле отсутствует → defaultValue `true`
- `{"date_joined": "2024-03-15T10:00:00Z"}` → `dateJoined` не null

---

### Ш-3.2 | Пробросить is_new_user через AuthProvider

**Файл:** `lib/providers/auth_provider.dart:88-109`

**Проблема:** `AuthService.verifySms()` уже возвращает `isNewUser` (реализовано в сервисе), но `AuthProvider.confirmOtp()` это поле игнорирует. Новые пользователи попадают сразу на главный экран без онбординга.

**Изменение:**

```dart
// Добавить поле:
bool isNewUser = false;

// В confirmOtp() — сохранить флаг:
final result = await _authService.verifySms(phone, code);
isNewUser = result.isNewUser;
await _tokenStorage.saveTokens(access: result.access, refresh: result.refresh);
await _loadProfile();
await _registerFcmIfPossible();
return isLoggedIn;
```

После перехода на главный экран (или онбординг) — сбросить: `isNewUser = false`.

**Тесты** (`test/providers/auth_provider_test.dart`):
- `AuthService` возвращает `isNewUser: true` → `provider.isNewUser == true`
- повторный вызов с `isNewUser: false` → `provider.isNewUser == false`

---

### Ш-3.3 | notifications_enabled в updateNotificationPreferences

**Файл:** `lib/providers/auth_provider.dart:131-156`

**Проблема:** Метод `updateNotificationPreferences` не поддерживает глобальный мастер-переключатель, хотя API (`PATCH /api/v1/users/profile/`) его принимает.

**Изменение:**

```dart
Future<void> updateNotificationPreferences({
  bool? events,
  bool? promotions,
  bool? closedEvents,
  bool? notificationsEnabled, // <-- добавить
}) async {
  // ...
  if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled;
  // ...
}
```

**Тесты:** mock-тест — PATCH-запрос содержит `notifications_enabled` при передаче параметра.

---

### Ш-3.4 | journeyStartLabel из dateJoined

**Файл:** `lib/providers/auth_provider.dart` — геттер `HeroUser get user`

**Проблема:** `journeyStartLabel` всегда `null`, потому что поле `date_joined` отсутствовало в модели (исправлено в Ш-3.1).

**Изменение в геттере `user`:**

```dart
HeroUser get user {
  final profile = currentUser;
  if (profile == null) return kAnonymousHero;
  final name = profile.displayName.isEmpty ? profile.phone : profile.displayName;
  return HeroUser(
    name: name.isEmpty ? 'Герой без имени' : name,
    phone: profile.phone,
    journeyStartLabel: _formatJourneyStart(profile.dateJoined),
    eventsCount: eventsCount,
  );
}

String? _formatJourneyStart(DateTime? dt) {
  if (dt == null) return null;
  const months = [
    '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];
  return '${months[dt.month]} ${dt.year}';
}
```

**Тесты:**
- `DateTime(2024, 3, 15)` → `'Март 2024'`
- `null` → `null`

---

### Ш-3.5 | eventsCount из API

**Файл:** новый `lib/data/repositories/event_reservation_repository.dart`

**Проблема:** `eventsCount` в профиле всегда равен 0 — реального запроса к API нет.

**Создать репозиторий:**

```dart
class EventReservationRepository {
  EventReservationRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;
  final Dio _dio;

  Future<int> fetchMyReservationsCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/reservations/my/',
    );
    final results = (response.data?['results'] as List?) ?? [];
    return results.length;
  }
}
```

В `AuthProvider`: добавить поле `int eventsCount = 0;`. После `_loadProfile()` вызывать репозиторий и сохранять счётчик в `eventsCount`. Геттер `user` (Ш-3.4) передаёт `eventsCount: eventsCount` в `HeroUser`.

**Тесты:**
- mock response с `results: [{...}, {...}]` → метод возвращает `2`
- пустой `results` → `0`

---

---

# АРХАТ — Слой UI

---

## А-1 | Удаление несуществующего функционала

**Ветка:** `fix/remove-fake-ui`
**Зависимости:** нет — стартует сразу

---

### А-1.1 | Убрать кнопку «ЗАКАЗАТЬ»

**Файл:** `lib/widgets/dish_elements.dart:393-430`

**Проблема:** `DishBookingCta` отображает `'ЗАКАЗАТЬ ЗА ${dish.price} ₸'` и при нажатии просто закрывает модальное окно (`Navigator.pop`). Функционала заказа в ТЗ и API нет. Кнопка вводит пользователя в заблуждение.

**Изменение:** Удалить класс `DishBookingCta` полностью. Найти все вызовы `DishBookingCta(...)` и убрать. Детальный экран блюда остаётся — без CTA-кнопки заказа.

**Тесты** (`test/widgets/dish_elements_test.dart`):
- открыть detail sheet блюда → текст `'ЗАКАЗАТЬ'` не найден в дереве виджетов

---

### А-1.2 | Убрать Like/Save/Share с видео-карточек

**Файл:** `lib/widgets/dish_elements.dart:150-193`

**Проблема:** `DishCardActionBar` со стейтом `_liked`/`_saved` — все действия локальные, на сервер ничего не уходит. API для лайков/сохранения нет в ТЗ.

**Изменение:** Удалить классы `DishCardActionBar`, `_DishCardActionBarState`, `_DishActionBtn`. Найти все места использования и убрать.

**Тесты:**
- в видео-карточке нет кнопок «Нравится», «Запомнить», «Поделиться»

---

### А-1.3 | Убрать диалог «Фотоотчёт»

**Файл:** `lib/screens/events_screen.dart:33-100`

**Проблема:** `_openPhotoReport` показывает случайные локальные интерьерные PNG, никак не связанные с конкретным событием. API не возвращает ссылки на фотоотчёт. Функция дезориентирует пользователя.

**Изменение:** Удалить метод `_openPhotoReport`. Удалить кнопку «Фотоотчёт» из карточки события. Поле `hasPhotoReport` в модели `ApiEvent` оставить — понадобится когда функционал появится на бэкенде.

**Тесты:**
- в карточке прошедшего события нет кнопки «Фотоотчёт»

---

## А-2 | Hero slider — фото из бэкенда

**Ветка:** `fix/hero-slider-from-api`
**Зависимости:** нет — `CoreInfo.heroSlides` уже парсится, блок независимый

---

### А-2.1 | Подключить heroSlides к слайдеру афиши

**Файл:** `lib/screens/events_screen.dart:420-464`

**Проблема:** `_AfishaHero` использует `PiligrimInteriorAssets.allInteriorPngs` — 21 локальный PNG. Фотографии должны приходить из синглтона `CoreInfo` через `heroSlides`.

**Изменение:**

1. Добавить в `_AfishaHero` параметр `imageUrls`:
```dart
class _AfishaHero extends StatefulWidget {
  const _AfishaHero({
    required this.selectedIndex,
    required this.onChanged,
    required this.imageUrls,
  });
  final List<String> imageUrls;
```

2. В родительском виджете передавать из `CoreInfoProvider`:
```dart
final coreInfo = context.watch<CoreInfoProvider>().coreInfo;
final imageUrls = (coreInfo?.heroImageUrls.isNotEmpty == true)
    ? coreInfo!.heroImageUrls
    : PiligrimInteriorAssets.triptychInteriorAmbient; // fallback
```

3. Внутри `_AfishaHero` использовать `widget.imageUrls`. Для сетевых URL — `CachedNetworkImage`, для локальных (fallback) — `Image.asset`.

**Тесты:**
- `CoreInfo` с непустым `heroSlides` → слайдер использует сетевые URL
- пустой `heroSlides` → слайдер показывает fallback локальные ассеты

---

## А-3 | Замена захардкоженных данных на CoreInfo

**Ветка:** `fix/hardcoded-data-to-api`
**Зависимости:** ⚠️ Ш-2.1 должен быть смёрджен

---

### А-3.1 | Карта — кнопки из CoreInfo

**Файлы:** `lib/screens/profile_screen.dart:865`, `lib/core/profile_data.dart:57-73`

**Проблема:** Кнопки 2ГИС / Google / Яндекс ведут на координаты-заглушку `51.128207,71.430544`. Правильные ссылки приходят из `CoreInfo`.

**Изменение в `profile_screen.dart`:**
```dart
final coreInfo = context.watch<CoreInfoProvider>().coreInfo;

final mapLinks = [
  if (coreInfo?.twogisLink != null)
    (label: '2ГИС', url: coreInfo!.twogisLink!, asset: 'assets/images/splash_path (1).svg'),
  if (coreInfo?.googleMapsLink != null)
    (label: 'Google', url: coreInfo!.googleMapsLink!, asset: 'assets/images/star_totem (1).svg'),
  if (coreInfo?.yandexMapsLink != null)
    (label: 'Яндекс', url: coreInfo!.yandexMapsLink!, asset: 'assets/images/wheel_totem (1).svg'),
];

// Если все три null — скрыть блок
if (mapLinks.isEmpty) return const SizedBox.shrink();
```

Константы `kMapTargets` и `kRestaurantCoords` в `lib/core/profile_data.dart` — удалить.

**Тесты:**
- с `twogisLink == null` кнопка «2ГИС» не рендерится
- с непустым `twogisLink` — рендерится с правильным URL

---

### А-3.2 | Пользовательское соглашение из CoreInfo

**Файл:** `lib/screens/profile_screen.dart:1275`

```dart
// БЫЛО:
onTap: () => onLaunch('https://piligrim.kz/terms'),

// СТАЛО — скрываем строку если поле null:
if (coreInfo?.termsOfService != null)
  _LegalRow(
    label: 'Пользовательское соглашение',
    onTap: () => onLaunch(coreInfo!.termsOfService!),
  ),
```

**Тесты:** с `termsOfService == null` строка не отображается.

---

### А-3.3 | Обратная связь из CoreInfo

**Файл:** `lib/screens/profile_screen.dart:1287`

```dart
// БЫЛО:
onTap: () => onLaunch('mailto:hello@piligrim.kz'),

// СТАЛО:
if (coreInfo?.feedbackUrl != null)
  _LegalRow(
    label: 'Обратная связь',
    accent: true,
    onTap: () => onLaunch(coreInfo!.feedbackUrl!),
  ),
```

**Тесты:** аналогично А-3.2.

---

### А-3.4 | Заметка о депозите из CoreInfo

**Файл:** `lib/screens/booking_screen.dart:386`

`CoreInfoProvider` уже подключён в этом экране (строка 176).

```dart
// БЫЛО (хардкод):
'Для выбранного стола может потребоваться депозит. Менеджер направит вас на звонок.'

// СТАЛО:
context.watch<CoreInfoProvider>().coreInfo?.bookingDepositNote
    ?? 'Для выбранного стола может потребоваться депозит. Уточните у менеджера.'
```

**Тесты:**
- с непустым `bookingDepositNote` отображается текст из API
- с `null` — фолбэк текст

---

## А-4 | Экраны профиля — новые фичи

**Ветка:** `fix/profile-screens`
**Зависимости:** ⚠️ Ш-3.1 и Ш-3.3 должны быть смёрджены (А-4.1), Ш-3.5 (А-4.2), Ш-3.2 (А-4.3)

---

### А-4.1 | Мастер-переключатель уведомлений

**Файл:** `lib/screens/profile_screen.dart:576-629`

**Проблема:** `_NotificationsCard` показывает только 3 категориальных переключателя. Отсутствует главный `notifications_enabled` — если пользователь его выключил на другом устройстве, приложение не отражает это состояние.

**Изменение:** добавить в `_NotificationsCard` строку-переключатель выше категорий:

```dart
_NotifRow(
  category: NotifCategory(
    id: 'global',
    label: 'Уведомления',
    subtitle: 'Включить все push-уведомления',
    iconAsset: 'assets/images/moon_totem (1).svg',
  ),
  isOn: currentUser?.notificationsEnabled ?? true,
  onChanged: (val) => onToggle('global', val),
),
const Divider(height: 1, color: PiligrimColors.divider, indent: 48),
// ... существующие категории ...
```

При `notificationsEnabled == false` — категории показывать задизабленными (opacity 0.4, `onChanged: null`).

В обработчике `_handleNotifToggle`:
```dart
case 'global':
  await auth.updateNotificationPreferences(notificationsEnabled: value);
```

**Тесты:**
- при `notificationsEnabled: false` категории визуально задизаблены
- переключение вызывает `updateNotificationPreferences(notificationsEnabled: ...)`

---

### А-4.2 | eventsCount в статистике профиля

**Файл:** `lib/screens/profile_screen.dart:473`

**Проблема:** `user.eventsCount` всегда `0` — реальных данных нет. После Ш-3.5 поле заполняется из API.

**Изменение:** Проверить, что `_user` берётся из `context.watch<AuthProvider>().user`, а не из `kDemoUser`. Поле `eventsCount` подтянется автоматически. Дополнительного кода не требуется.

**Проверка:** убедиться что нигде в `ProfileScreen` не используется `kDemoUser` как источник данных.

---

### А-4.3 | Онбординг-экран для новых пользователей

**Файл:** новый `lib/screens/onboarding_screen.dart`, изменение `lib/screens/splash_screen.dart`
**Зависит от:** Ш-3.2

**Изменение в `SplashScreen._goToHome()`:**
```dart
void _goToHome() {
  final auth = context.read<AuthProvider>();
  if (auth.isNewUser) {
    auth.isNewUser = false;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
    return;
  }
  // существующий код перехода на RootShell
}
```

`OnboardingScreen` — минимальный экран: приветствие, необязательное поле имени, кнопка «Начать путь» → `PATCH /api/v1/users/profile/` → переход на `RootShell`.

**Тесты:**
- при `isNewUser == true` навигация идёт на `OnboardingScreen`
- при `isNewUser == false` навигация идёт на `RootShell`

---

## А-5 | Документация

**Ветка:** `fix/readme-urls`
**Зависимости:** нет

---

### А-5.1 | Исправить неверные URL в README.md

**Файл:** `README.md:116-117`

| Неверно | Верно |
|---|---|
| `POST /api/v1/bookings/create/` | `POST /api/v1/bookings/` |
| `GET /api/v1/bookings/my/` | `GET /api/v1/bookings/` |
| `POST /api/v1/notifications/devices/register/` | `POST /api/v1/notifications/device/register/` |

---

---

# Итоговая таблица тикетов

| # | Разработчик | Тикет | Приоритет | Зависит от |
|---|---|---|---|---|
| Ш-1.1 | Шерхан | Видеополе блюда (`video_url`) | P0 | — |
| Ш-1.2 | Шерхан | Формат времени (`HH:MM:SS` на API) | P0 | — |
| Ш-1.3 | Шерхан | Цена события (decimal + поле `price`) | P0 | — |
| Ш-2.1 | Шерхан | CoreInfo — 6 новых полей | P1 | — |
| Ш-3.1 | Шерхан | UserProfile — `notificationsEnabled` + `dateJoined` | P1 | — |
| Ш-3.2 | Шерхан | `is_new_user` в `AuthProvider` | P1 | — |
| Ш-3.3 | Шерхан | `notifications_enabled` в `updateNotificationPreferences` | P1 | Ш-3.1 |
| Ш-3.4 | Шерхан | `journeyStartLabel` из `dateJoined` | P2 | Ш-3.1 |
| Ш-3.5 | Шерхан | `EventReservationRepository` + `eventsCount` | P2 | — |
| А-1.1 | Архат | Удалить кнопку «ЗАКАЗАТЬ» | P0 | — |
| А-1.2 | Архат | Удалить Like/Save/Share | P0 | — |
| А-1.3 | Архат | Удалить диалог «Фотоотчёт» | P0 | — |
| А-2.1 | Архат | Hero slider — фото из `CoreInfo.heroSlides` | P1 | — |
| А-3.1 | Архат | Карта — кнопки из `CoreInfo` | P1 | Ш-2.1 |
| А-3.2 | Архат | Пользовательское соглашение из `CoreInfo` | P1 | Ш-2.1 |
| А-3.3 | Архат | Обратная связь из `CoreInfo` | P1 | Ш-2.1 |
| А-3.4 | Архат | Заметка о депозите из `CoreInfo` | P1 | Ш-2.1 |
| А-4.1 | Архат | Мастер-переключатель уведомлений | P2 | Ш-3.1, Ш-3.3 |
| А-4.2 | Архат | `eventsCount` в UI профиля | P2 | Ш-3.5 |
| А-4.3 | Архат | Онбординг-экран | P2 | Ш-3.2 |
| А-5.1 | Архат | Исправить URL в README.md | P3 | — |

**P0** — исправить в первую очередь (данные ломаются или UI вводит в заблуждение).
**P1** — необходимо для корректной работы по ТЗ.
**P2** — завершает функционал профиля.
**P3** — документация.

---

# Timeline

```
День 1–2 (параллельно)
  Шерхан: Ш-1 (три критических бага) + Ш-2.1 (CoreInfo поля) + Ш-3.1 (UserProfile поля)
  Архат:  А-1 (удалить ЗАКАЗАТЬ / лайки / фотоотчёт) + А-2.1 (hero slider)

День 3–4 (параллельно)
  Шерхан: Ш-3.2 (is_new_user) + Ш-3.3 (notifications_enabled) + Ш-3.4 (journeyStart) + Ш-3.5 (eventsCount)
  Архат:  А-3 (карта, ссылки, депозит) — стартует после мёрджа Ш-2.1

День 5 (параллельно)
  Шерхан: code review, тесты
  Архат:  А-4 (переключатель, онбординг) + А-5.1 (README)
```

---

# Верификация после каждого блока

### После Ш-1 + А-1
```bash
flutter run
```
- Видео в ленте блюд воспроизводится (поле `video_url`)
- Кнопка «ЗАКАЗАТЬ» отсутствует на детальном экране блюда
- Лайк/Share/Save кнопки отсутствуют на видео-карточках
- Кнопка «Фотоотчёт» отсутствует на карточках событий

### После Ш-2 + А-3
- Кнопки карты показывают реальные ссылки из CoreInfo (или скрыты если null)
- Строка «Пользовательское соглашение» скрыта если `termsOfService == null`
- Заметка о депозите показывает текст из `bookingDepositNote`

### После Ш-3 + А-4
- Бронирование успешно уходит на сервер (время в формате `HH:MM:SS`)
- Профиль: мастер-переключатель уведомлений работает
- Профиль: `eventsCount` показывает реальное число, `journeyStartLabel` заполнен
- Новый пользователь после верификации OTP попадает на онбординг

### Запуск тестов
```bash
flutter test                  # все тесты
flutter test test/data/       # только unit tests
flutter test test/widgets/    # только widget tests
flutter test test/screens/    # только screen tests
flutter test --coverage       # с покрытием
```

# PILIGRIM — Flutter App: Roadmap & Tickets

> Документ описывает пошаговый план интеграции Flutter-приложения с бэкендом Django REST API.
> Разработчики: **Архат** (инфраструктура / бэкенд-интеграция) и **Шерхан** (контент / UI).

---

## Контекст

Приложение имеет полностью готовый UI на моковых данных (8 экранов, 25+ виджетов, брендовая тема). Бэкенд полностью написан и задокументирован (Django REST + Celery + FCM). Цель — подключить Flutter к реальному API, добавить аутентификацию, пуш-уведомления и устранить расхождение навигационной структуры с ТЗ.

**Ключевое расхождение с ТЗ:**
- Текущие 5 табов: `Home / Menu / Events / Booking / Profile`
- По ТЗ: `Home / Menu / Интерьер / Афиша / Профиль`

Бронирование → quick action с главного экрана (уже есть `HomeTotemPathRow` + `home_action_block.dart`).

---

## Архитектурные решения

| Решение | Выбор | Причина |
|---|---|---|
| HTTP client | `dio ^5.7` | JWT-интерцептор, retry, конфигурируемость |
| Хранение токенов | `flutter_secure_storage ^9.2` | Безопасность, keychain/keystore |
| State management | `provider ^6.1` + `ChangeNotifier` | Минимальная надстройка над уже используемым `ValueNotifier`/`InheritedNotifier` |
| Изображения из API | `cached_network_image ^3.4` | Кэш, плейсхолдеры |
| Видео | `video_player ^2.9` | Официальный Flutter-пакет, достаточен для ленты |
| Push | `firebase_core ^3.6` + `firebase_messaging ^15.1` | Бэкенд уже использует FCM |
| UUID | `uuid ^4.5` | Idempotency-Key для booking/event reservation |
| Тестирование | `mocktail ^1.0` | Мокирование Dio и сервисов без кодогенерации |

### Новые пакеты (pubspec.yaml)

```yaml
dependencies:
  dio: ^5.7.0
  flutter_secure_storage: ^9.2.2
  provider: ^6.1.2
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  video_player: ^2.9.1
  cached_network_image: ^3.4.1
  uuid: ^4.5.1

dev_dependencies:
  mocktail: ^1.0.4
```

---

## Новая структура директорий

```
lib/
├── data/
│   ├── models/               ← Dart-классы fromJson/toJson (без Flutter)
│   │   ├── api_dish.dart
│   │   ├── api_category.dart
│   │   ├── api_event.dart
│   │   ├── api_booking.dart
│   │   ├── api_user.dart
│   │   ├── api_core_info.dart
│   │   └── api_interior.dart
│   ├── services/
│   │   ├── api_client.dart       ← Dio singleton + interceptors
│   │   ├── auth_service.dart     ← request-sms, verify-sms, logout
│   │   ├── token_storage.dart    ← flutter_secure_storage wrapper
│   │   └── fcm_service.dart      ← Firebase init + device registration
│   └── repositories/
│       ├── menu_repository.dart
│       ├── events_repository.dart
│       ├── booking_repository.dart
│       ├── profile_repository.dart
│       └── core_repository.dart
├── providers/
│   ├── auth_provider.dart
│   ├── core_info_provider.dart
│   ├── menu_provider.dart
│   ├── events_provider.dart
│   └── booking_provider.dart
├── screens/
│   ├── interior_screen.dart        ← НОВЫЙ (3-й таб)
│   ├── auth/
│   │   ├── phone_entry_screen.dart ← НОВЫЙ
│   │   └── otp_screen.dart         ← НОВЫЙ
│   └── booking_history_screen.dart ← НОВЫЙ
docs/
└── flutter/                        ← Документация по Flutter-интеграции
    ├── api_client.md
    ├── auth.md
    ├── menu.md
    ├── events.md
    ├── booking.md
    ├── notifications.md
    └── core_info.md
```

---

## Изменение навигации (важно понять перед стартом)

**Файлы:** `lib/main.dart`, `lib/widgets/bottom_nav_bar.dart`, `lib/widgets/home_action_block.dart`, `lib/widgets/home_event_block.dart`, `lib/core/home_data.dart`

Новый порядок `IndexedStack`: `Home(0) / Menu(1) / InteriorScreen(2) / EventsScreen(3) / ProfileScreen(4)`

- `kMenuCategories[3]` (id: `book`) → `navIndex: -1` (sentinel)
- В `home_totem_path.dart._onItemTap`: если `navIndex == -1` → `Navigator.push(BookingScreen)`
- `home_action_block.dart`: `EmberCta.onTap` → `Navigator.push(BookingScreen)`
- `home_event_block.dart`: `onNavigate?.call(2)` → `onNavigate?.call(3)`

---

## Auth Guard Pattern (используется везде)

```dart
if (!context.read<AuthProvider>().isLoggedIn) {
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => PhoneEntryScreen(),
  ));
  if (!context.read<AuthProvider>().isLoggedIn) return;
}
// продолжить действие
```

---

## MultiProvider (lib/main.dart)

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
    ChangeNotifierProvider(create: (_) => CoreInfoProvider()..load()),
    ChangeNotifierProvider(create: (_) => MenuProvider()),
    ChangeNotifierProvider(create: (_) => EventsProvider()),
    ChangeNotifierProvider(create: (_) => BookingProvider()),
  ],
  child: AmbientPresetScope(controller: _ambientCtrl, child: MaterialApp(...)),
)
```

---

---

# Блоки задач

---

## Блок 1 — API Client + Firebase Setup
**Разработчик:** Архат
**Ветка:** `feature/infra-api-client`
**Зависимости:** нет (стартовый блок)

### Тикет 1.1 — Добавить пакеты + настроить Firebase

**Файлы:** `pubspec.yaml`, `lib/main.dart`, `android/app/build.gradle.kts`, `android/app/google-services.json` (новый), `ios/Runner/GoogleService-Info.plist` (новый), `ios/Runner/AppDelegate.swift`, `android/app/src/main/AndroidManifest.xml`

- Добавить все 9 пакетов через `flutter pub add`
- Запустить `flutterfire configure` → сгенерирует Firebase-конфиги
- В `main()`: `WidgetsFlutterBinding.ensureInitialized()` + `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` перед `runApp`
- `AndroidManifest.xml`: добавить `android:allowBackup="false"` (безопасность токенов)
- iOS `Info.plist`: добавить `FirebaseAppDelegateProxyEnabled = NO`

### Тикет 1.2 — API client + token storage

**Файлы:** `lib/data/services/api_client.dart`, `lib/data/services/token_storage.dart`

`token_storage.dart` — обёртка над `flutter_secure_storage`:
```dart
Future<void> saveTokens({required String access, required String refresh})
Future<String?> readAccess()
Future<String?> readRefresh()
Future<void> clearTokens()
```

`api_client.dart` — `DioClient` singleton:
- `baseUrl = 'https://piligrim.kz/api/v1'`
- `connectTimeout: 30s, receiveTimeout: 30s`
- `AuthInterceptor`: читает access-токен → `Authorization: Bearer`. При 401 → рефреш → retry. При повторном 401 → `clearTokens()` + `onUnauthenticated.add(null)` (StreamController)
- `LoggingInterceptor` (только `kDebugMode`)

---

### Тесты для Блока 1

**Файлы:** `test/data/services/token_storage_test.dart`, `test/data/services/api_client_test.dart`

```
token_storage_test.dart:
  ✓ saveTokens() → readAccess() возвращает сохранённый access
  ✓ saveTokens() → readRefresh() возвращает сохранённый refresh
  ✓ clearTokens() → readAccess() возвращает null
  ✓ clearTokens() → readRefresh() возвращает null

api_client_test.dart (с mocktail):
  ✓ AuthInterceptor добавляет заголовок Authorization при наличии токена
  ✓ AuthInterceptor НЕ добавляет заголовок когда токен null
  ✓ При 401 → вызывается refresh endpoint
  ✓ После успешного refresh → исходный запрос повторяется
  ✓ При повторном 401 → clearTokens() вызван
```

### Документация для Блока 1

**Файл:** `docs/flutter/api_client.md`

Содержит:
- Описание `DioClient` и как его использовать
- Схема JWT flow (request → 401 → refresh → retry)
- `TokenStorage` API
- `baseUrl` конфигурация (где менять для dev/prod)
- Пример добавления нового endpoint

---

## Блок 2 — Data Models + Auth Logic
**Разработчик:** Шерхан
**Ветка:** `feature/data-models-auth`
**Зависимости:** Блок 1 (api_client.dart, token_storage.dart)

### Тикет 2.1 — Data models (fromJson/toJson)

**Файлы:** `lib/data/models/` — 7 новых файлов

Чистые Dart-классы, только `dart:core`. Каждый — `factory fromJson(Map<String, dynamic>)` и, где нужно, `toJson()`.

| Класс | Ключевые поля |
|---|---|
| `ApiDish` | id, name, description, price (int), category (int), tags, allergens, imageUrl?, videoUrl?, weight, story, isActive |
| `ApiCategory` | id, name, slug |
| `ApiEvent` | id, title, description, startsAt (DateTime.parse), format (open/closed), coverUrl?, priceFrom (int?), isPast |
| `ApiBooking` | id, guestName, phone, date, time, guestsCount, zone?, comment?, status |
| `BookingRequest` | поля + `toJson()` |
| `UserProfile` | id, phone, firstName, lastName, notifyEvents, notifyPromotions, notifyClosedEvents |
| `CoreInfo` | address, workingHours, isOpenNow, phone, socialLinks, heroSlides, heroVideoUrl?, bookingDepositRequired, visitRules, privacyPolicy |
| `InteriorSlide` | id, zone, zoneDisplay, imageUrl, caption?, order |

**Реиспользовать:** `PiligrimNewsPost` из `lib/data/events_news_data.dart` — структура совпадает с API `/events/news/`. Не создавать дублирующий класс.

### Тикет 2.2 — Auth service + AuthProvider

**Файлы:** `lib/data/services/auth_service.dart`, `lib/providers/auth_provider.dart`

`auth_service.dart`:
```dart
Future<void> requestSms(String phone)
Future<({String access, String refresh, bool isNewUser})> verifySms(String phone, String code)
Future<void> logout(String refreshToken)
```

`auth_provider.dart` — `AuthProvider extends ChangeNotifier`:
- State: `UserProfile? currentUser`, `bool isLoading`, `String? error`
- `Future<void> init()` — читает access из `TokenStorage`; если есть, GET `/users/profile/` → `currentUser`
- `Future<void> sendOtp(String phone)`
- `Future<bool> confirmOtp(String phone, String code)` — сохраняет токены, загружает профиль, регистрирует FCM-токен
- `Future<void> logout()`
- `bool get isLoggedIn => currentUser != null`
- `Future<void> updateNotificationPreferences({bool? events, bool? promotions, bool? closedEvents})` — PATCH `/users/profile/` + обновляет `currentUser`

---

### Тесты для Блока 2

**Файлы:** `test/data/models/`, `test/providers/auth_provider_test.dart`

```
api_dish_test.dart:
  ✓ fromJson() корректно парсит все поля
  ✓ fromJson() не падает при null imageUrl / videoUrl
  ✓ fromJson() конвертирует price из строки в int

api_event_test.dart:
  ✓ fromJson() парсит startsAt как DateTime
  ✓ fromJson() распознаёт format: "open" / "closed"

booking_request_test.dart:
  ✓ toJson() формирует корректный Map для POST-тела
  ✓ toJson() не включает null поля (zone, comment)

auth_provider_test.dart:
  ✓ init() — если нет токена → isLoggedIn == false
  ✓ init() — если есть токен → загружает профиль → isLoggedIn == true
  ✓ confirmOtp() → сохраняет токены + устанавливает currentUser
  ✓ logout() → очищает токены + currentUser == null
  ✓ updateNotificationPreferences() → патчит профиль + обновляет currentUser
```

### Документация для Блока 2

**Файл:** `docs/flutter/auth.md`

Содержит:
- Auth flow диаграмма: requestSms → verifySms → сохранение токенов → профиль
- Описание `AuthProvider` API (все публичные методы)
- Где и как использовать Auth Guard в новых экранах
- Схема моделей (поля, типы, nullable)
- `BookingRequest.toJson()` пример

---

## Блок 3 — Navigation Restructure + Auth Screens
**Разработчик:** Архат
**Ветка:** `feature/nav-auth-screens`
**Зависимости:** Блок 2 (AuthProvider)

### Тикет 3.1 — Navigation restructure + InteriorScreen shell

**Файлы:** `lib/main.dart`, `lib/widgets/bottom_nav_bar.dart`, `lib/widgets/home_action_block.dart`, `lib/widgets/home_event_block.dart`, `lib/core/home_data.dart`, `lib/screens/interior_screen.dart` (новый)

`interior_screen.dart` — временная заглушка:
- `PiligrimBackground` + `GridView.builder` из `PiligrimInteriorAssets.allInteriorPngs` (2 колонки, `childAspectRatio: 0.75`)
- Будет полностью заменён в Блоке 6

Изменения навигации (детали описаны в секции выше).

### Тикет 3.2 — Auth screens: PhoneEntryScreen + OTPScreen

**Файлы:** `lib/screens/auth/phone_entry_screen.dart`, `lib/screens/auth/otp_screen.dart`

`phone_entry_screen.dart`:
- `PiligrimBackground` + логотип + поле телефона `+7 7XX XXX XX XX`
- Валидация: strip non-digits, требуется 11 цифр (`7XXXXXXXXXX`)
- `AuthProvider.sendOtp()` → push `OTPScreen(phone: phone)`
- States: loading (кнопка disabled), error (SnackBar)

`otp_screen.dart`:
- Принимает `phone` и `returnAfterLogin: bool`
- Одно поле `TextFormField(maxLength: 6, keyboardType: numeric)` — стилизованное под бренд
- Таймер 60 сек → кнопка "Отправить повторно"
- `AuthProvider.confirmOtp()` → на успех: `Navigator.pop()`

---

### Тесты для Блока 3

**Файлы:** `test/screens/auth/phone_entry_screen_test.dart`, `test/screens/auth/otp_screen_test.dart`

```
phone_entry_screen_test.dart:
  ✓ Кнопка отправки задизаблена при пустом поле
  ✓ Кнопка активна при корректном номере (11 цифр)
  ✓ Невалидный номер (менее 11 цифр) → SnackBar с ошибкой
  ✓ При успешном sendOtp() → переход на OTPScreen

otp_screen_test.dart:
  ✓ Кнопка подтверждения задизаблена при коде < 6 символов
  ✓ Кнопка "Повторить" скрыта до истечения 60 сек таймера
  ✓ При успешном confirmOtp() → Navigator.pop() вызван

navigation_test.dart:
  ✓ Таб 2 открывает InteriorScreen
  ✓ Таб 3 открывает EventsScreen
  ✓ Кнопка "Забронировать" открывает BookingScreen через push (не меняет таб)
```

### Документация для Блока 3

**Файл:** `docs/flutter/auth.md` (дополнение)

Добавить раздел:
- Навигационная схема (5 табов, новый порядок)
- Как добавить новый экран, требующий авторизации
- Экраны `PhoneEntryScreen` и `OTPScreen` — параметры и поведение
- Где и когда показывать Auth Guard

---

## Блок 4 — Core Info + FCM
**Разработчик:** Шерхан
**Ветка:** `feature/core-info-fcm`
**Зависимости:** Блок 1 (api_client), Блок 2 (models, AuthProvider)

### Тикет 4.1 — CoreInfoProvider + wire HomeScreen/ProfileScreen

**Файлы:** `lib/data/repositories/core_repository.dart`, `lib/providers/core_info_provider.dart`, `lib/screens/home_screen.dart`, `lib/screens/profile_screen.dart`

`core_repository.dart`:
```dart
Future<CoreInfo> fetchCoreInfo()              // GET /core/info/
Future<List<InteriorSlide>> fetchInterior()   // GET /core/interior/
Future<({String minVersion, String latestVersion, String storeUrl})>
    fetchAppVersion(String platform)           // GET /core/app-version/?platform=
```

`core_info_provider.dart` — guard от двойного fetch: `if (_isLoading || _coreInfo != null) return;`

`home_screen.dart` — `context.watch<CoreInfoProvider>()`:
- `HomeStatusLine` → `coreInfo?.isOpenNow` (fallback на mock)
- `HomeHeroSection` → `coreInfo?.heroSlides` (fallback — локальные ассеты)

`profile_screen.dart` → `_HoursCard`:
- Заменить `kRestaurantInfo.scheduleLabel` на `coreInfo?.workingHours`

### Тикет 4.2 — FCM service

**Файл:** `lib/data/services/fcm_service.dart`

```dart
Future<void> init()                              // requestPermission + listeners
Future<String?> getToken()
Future<void> registerTokenWithServer(Dio dio)    // POST /notifications/device/register/
```

- `onMessage` → брендовый in-app SnackBar (`PiligrimColors.earth` bg, `PiligrimColors.sky` текст)
- `onMessageOpenedApp` → навигация по `data['type']`: `booking` → индекс 4, `event` → индекс 3
- В `AuthProvider.confirmOtp()` после сохранения профиля → `FcmService().registerTokenWithServer()`

---

### Тесты для Блока 4

**Файлы:** `test/data/repositories/core_repository_test.dart`, `test/providers/core_info_provider_test.dart`

```
core_repository_test.dart:
  ✓ fetchCoreInfo() возвращает CoreInfo при 200
  ✓ fetchCoreInfo() бросает исключение при 500
  ✓ fetchInterior() возвращает список InteriorSlide
  ✓ fetchAppVersion() парсит min/latest/storeUrl

core_info_provider_test.dart:
  ✓ load() устанавливает coreInfo после успешного запроса
  ✓ load() устанавливает error при сетевой ошибке
  ✓ load() НЕ делает двойной запрос если coreInfo уже загружен
  ✓ isOpenNow корректно читается из coreInfo

fcm_service_test.dart:
  ✓ registerTokenWithServer() вызывает POST /notifications/device/register/
  ✓ registerTokenWithServer() не падает если getToken() вернул null
```

### Документация для Блока 4

**Файлы:** `docs/flutter/core_info.md`, `docs/flutter/notifications.md`

`core_info.md`:
- Какие данные приходят с `/core/info/` и как используются
- Как `CoreInfoProvider.load()` вызывается при старте
- Паттерн fallback на локальные данные

`notifications.md`:
- Как работает FCM в приложении
- Какие категории уведомлений существуют (`events`, `promotions`, `closed_events`)
- Как тестировать пуши локально (Firebase Console)
- Формат `data`-поля в пуше для навигации

---

## Блок 5 — Menu Integration
**Разработчик:** Архат
**Ветка:** `feature/menu-integration`
**Зависимости:** Блок 1, Блок 2 (models)

### Тикет 5.1 — Menu repository + MenuProvider

**Файлы:** `lib/data/repositories/menu_repository.dart`, `lib/providers/menu_provider.dart`

`menu_repository.dart`:
```dart
Future<List<ApiCategory>> fetchCategories()
Future<({List<ApiDish> dishes, bool hasMore})> fetchDishes({
  int? categoryId, List<int>? tagIds, String? search, int page = 1,
})
```

`menu_provider.dart` — `MenuProvider extends ChangeNotifier`:
- State: `categories`, `dishes`, `isLoading`, `isLoadingMore`, `hasMore`, `_page`, `activeCategoryId`, `searchQuery`
- `loadDishes({bool refresh = false})` — refresh сбрасывает страницу
- `setCategory(String? id)` — сброс + перезагрузка
- `setSearch(String q)` — debounce 400 мс

### Тикет 5.2 — Wire MenuScreen + video_player + cached images

**Файлы:** `lib/screens/menu_screen.dart`, `lib/widgets/dish_video_card.dart`, `lib/widgets/dish_elements.dart`

`menu_screen.dart`:
- `context.watch<MenuProvider>()` вместо `kDishes` / `kDishCategories`
- Infinite scroll: `ScrollController` listener → при proximity к концу и `hasMore == true` → `menuProvider.loadDishes()`
- `CircularProgressIndicator` в `PiligrimColors.water` при `isLoading`

`dish_video_card.dart`:
- Если `dish.videoUrl != null` → `VideoPlayerController.networkUrl(Uri.parse(dish.videoUrl!))`
- Пауза (не dispose) когда `isActive` → false; возобновление когда → true
- `addListener(() => setState(() {}))` для rebuild при буферизации
- Fallback: существующий gradient если `videoUrl == null`

`dish_elements.dart` (detail sheet):
- `CachedNetworkImage(imageUrl: dish.imageUrl ?? '')` когда `imageUrl != null`
- Fallback: существующий `_CinematicBackground`

---

### Тесты для Блока 5

**Файлы:** `test/data/repositories/menu_repository_test.dart`, `test/providers/menu_provider_test.dart`

```
menu_repository_test.dart:
  ✓ fetchCategories() парсит список ApiCategory
  ✓ fetchDishes() без фильтров возвращает первую страницу
  ✓ fetchDishes(categoryId: 2) добавляет query param category_id=2
  ✓ fetchDishes() устанавливает hasMore=false когда next == null
  ✓ fetchDishes(search: 'стейк') добавляет query param search=стейк

menu_provider_test.dart:
  ✓ loadDishes() на пустом state → isLoading=true → isLoading=false
  ✓ loadDishes() добавляет dishes в список
  ✓ loadDishes() с hasMore=false не делает повторный запрос
  ✓ setCategory() сбрасывает список и запрашивает заново
  ✓ setSearch() с debounce 400 мс не делает несколько запросов подряд
```

### Документация для Блока 5

**Файл:** `docs/flutter/menu.md`

Содержит:
- Описание dual-mode (feed / classic) и как переключаться
- `MenuProvider` API: все методы и поля
- Как работает пагинация (бесконечная прокрутка)
- Как добавить новый тег или фильтр
- Как `VideoPlayerController` управляется в `DishVideoCard` (lifecycle)

---

## Блок 6 — Events Integration
**Разработчик:** Шерхан
**Ветка:** `feature/events-integration`
**Зависимости:** Блок 1, Блок 2 (models), Блок 3 (InteriorScreen shell), Блок 4 (CoreInfoProvider)

### Тикет 6.1 — Events repository + EventsProvider

**Файлы:** `lib/data/repositories/events_repository.dart`, `lib/providers/events_provider.dart`

`events_repository.dart`:
```dart
Future<List<ApiEvent>> fetchUpcoming({int page = 1})
Future<List<ApiEvent>> fetchArchived({int page = 1})
Future<List<PiligrimNewsPost>> fetchNews({int page = 1})  // реиспользовать существующий класс
Future<void> createReservation(int eventId, int guestsCount)
  // POST /events/reservations/create/ + Idempotency-Key: Uuid().v4()
Future<List<ApiReservation>> fetchMyReservations()
```

`events_provider.dart` — loading flags per list. `Future<void> reserveEvent(int, int)`.

### Тикет 6.2 — Wire EventsScreen + EventDetailScreen

**Файлы:** `lib/screens/events_screen.dart`, `lib/screens/event_detail_screen.dart`, `lib/widgets/event_signup_sheet.dart`

`events_screen.dart`:
- Заменить `buildMockEvents()` / `mockNewsPosts()` на `EventsProvider`
- `Image.asset(event.coverAssetPath)` → `CachedNetworkImage(imageUrl: event.coverUrl)`
- `initState`: `context.read<EventsProvider>().loadUpcoming()` и т.д.

`event_detail_screen.dart`:
- Параметр меняется: `PiligrimEvent` → `ApiEvent`
- Обновить все поля: `event.coverUrl`, `event.startsAt`

`event_signup_sheet.dart`:
- Добавить параметр `int eventId`
- Auth guard: `if (!auth.isLoggedIn)` → pop sheet → push `PhoneEntryScreen`
- Заменить mock submit на `EventsProvider.reserveEvent(eventId, guestsCount)`
- Поля: только `guestsCount` (stepper) — имя/телефон берётся из токена на бэке

### Тикет 6.3 — Wire InteriorScreen к API

**Файл:** `lib/screens/interior_screen.dart` (замена заглушки из Блока 3)

- `context.watch<CoreInfoProvider>().interiorSlides` вместо локальных ассетов
- `CachedNetworkImage` с zone label overlay (`slide.zoneDisplay`) и caption
- Fallback на локальные ассеты при пустом списке

---

### Тесты для Блока 6

**Файлы:** `test/data/repositories/events_repository_test.dart`, `test/providers/events_provider_test.dart`, `test/widgets/event_signup_sheet_test.dart`

```
events_repository_test.dart:
  ✓ fetchUpcoming() возвращает список ApiEvent
  ✓ fetchNews() возвращает список PiligrimNewsPost (реиспользование класса)
  ✓ createReservation() отправляет POST с Idempotency-Key заголовком
  ✓ createReservation() бросает исключение если пользователь не авторизован (401)

events_provider_test.dart:
  ✓ loadUpcoming() устанавливает список событий
  ✓ reserveEvent() при успехе не бросает ошибку
  ✓ reserveEvent() при 400 устанавливает error сообщение

event_signup_sheet_test.dart:
  ✓ При isLoggedIn=false → pop sheet + push PhoneEntryScreen
  ✓ Stepper не позволяет выбрать 0 гостей
  ✓ Кнопка submit вызывает EventsProvider.reserveEvent()
```

### Документация для Блока 6

**Файлы:** `docs/flutter/events.md`

Содержит:
- Структура экрана Events (табы: upcoming / archived / news)
- `EventsProvider` API: все методы
- Как работает регистрация на мероприятие (EventSignupSheet + Auth guard)
- Как интегрируется InteriorScreen с CoreInfoProvider
- Fallback-логика при отсутствии интернета

---

## Блок 7 — Booking Integration
**Разработчик:** Архат
**Ветка:** `feature/booking-integration`
**Зависимости:** Блок 2 (models, AuthProvider), Блок 3 (auth screens), Блок 4 (CoreInfoProvider)

### Тикет 7.1 — Booking repository + BookingProvider

**Файлы:** `lib/data/repositories/booking_repository.dart`, `lib/providers/booking_provider.dart`

`booking_repository.dart`:
```dart
Future<void> createBooking(BookingRequest req)
  // POST /bookings/ + Idempotency-Key: Uuid().v4()
Future<List<ApiBooking>> fetchHistory({int page = 1})
```

`booking_provider.dart` — State: `isSubmitting`, `isSuccess`, `error`, `history`. Methods: `submitBooking(BookingRequest)`, `loadHistory()`.

### Тикет 7.2 — Wire BookingScreen к API

**Файл:** `lib/screens/booking_screen.dart`

- Auth guard перед submit
- `_phoneCtrl` prefill: `AuthProvider.currentUser?.phone`
- `_depositRequired`: из `CoreInfoProvider.coreInfo?.bookingDepositRequired`
- Зоны: `['main', 'terrace', 'private']` (статически, как в API)
- Submit → `BookingProvider.submitBooking()` → success state / SnackBar для ошибки

### Тикет 7.3 — BookingHistoryScreen + profile stats

**Файл:** `lib/screens/booking_history_screen.dart`

Список `ApiBooking` из `BookingProvider.history`. Каждая карточка: дата, время, гостей, зона, badge статуса:
- `pending` → `PiligrimColors.steppe`
- `confirmed` → `PiligrimColors.water`
- `completed` → dim green
- `canceled` → grey

Pull-to-refresh. Empty state с тотем-иконкой.

`profile_screen.dart` → `_StatsRow`:
- `bookingsCount` из `BookingProvider.history.length`
- `_StatCard` tappable → push `BookingHistoryScreen`

---

### Тесты для Блока 7

**Файлы:** `test/data/repositories/booking_repository_test.dart`, `test/providers/booking_provider_test.dart`, `test/screens/booking_screen_test.dart`

```
booking_repository_test.dart:
  ✓ createBooking() отправляет POST с Idempotency-Key заголовком
  ✓ createBooking() body содержит корректные поля из BookingRequest
  ✓ createBooking() бросает исключение при 400 (validation error)
  ✓ fetchHistory() возвращает список ApiBooking

booking_provider_test.dart:
  ✓ submitBooking() устанавливает isSubmitting=true → false
  ✓ submitBooking() при успехе → isSuccess=true
  ✓ submitBooking() при ошибке → error != null

booking_screen_test.dart:
  ✓ При isLoggedIn=false → submit → push PhoneEntryScreen
  ✓ Поле телефона prefilled из AuthProvider.currentUser.phone
  ✓ Если depositRequired=true → предупреждение видно
  ✓ При успешном submitBooking() → success state отображается
```

### Документация для Блока 7

**Файл:** `docs/flutter/booking.md`

Содержит:
- Схема состояний бронирования (pending → confirmed → completed/canceled)
- `BookingProvider` API: все методы
- Idempotency-Key: зачем нужен и где генерируется
- Как работает prefill телефона из профиля
- Статусы и их цветовое кодирование в `BookingHistoryScreen`

---

## Блок 8 — Profile Integration
**Разработчик:** Шерхан
**Ветка:** `feature/profile-integration`
**Зависимости:** Блок 2 (AuthProvider), Блок 4 (CoreInfoProvider), Блок 7 (BookingProvider)

### Тикет 8.1 — Wire ProfileScreen к API

**Файлы:** `lib/data/repositories/profile_repository.dart`, `lib/screens/profile_screen.dart`

`profile_repository.dart`:
```dart
Future<UserProfile> fetchProfile()
Future<UserProfile> updateProfile(Map<String, dynamic> patch) // PATCH /users/profile/
```

Методы добавить в `AuthProvider.updateNotificationPreferences` — отдельный provider не создавать.

`profile_screen.dart`:
- `_user` → `context.watch<AuthProvider>().currentUser`
- `_notifState` Map → из `user?.notifyEvents / notifyPromotions / notifyClosedEvents`; onChange → `AuthProvider.updateNotificationPreferences(...)`
- `_HeroHeader` "НАЧАТЬ ПУТЬ" → push `PhoneEntryScreen`
- `_LegalFooter` privacy URL → `CoreInfoProvider.coreInfo?.privacyPolicy`
- `_StatsRow` bookingsCount → `BookingProvider.history.length`

---

### Тесты для Блока 8

**Файлы:** `test/data/repositories/profile_repository_test.dart`, `test/screens/profile_screen_test.dart`

```
profile_repository_test.dart:
  ✓ fetchProfile() возвращает UserProfile
  ✓ updateProfile({'notify_events': false}) → PATCH с корректным телом

profile_screen_test.dart:
  ✓ При isLoggedIn=false → "НАЧАТЬ ПУТЬ" кнопка видна
  ✓ При isLoggedIn=true → имя и телефон из AuthProvider.currentUser
  ✓ Переключение notify_events → AuthProvider.updateNotificationPreferences() вызван
  ✓ Тап на "Бронирований" → push BookingHistoryScreen
  ✓ Privacy link → URL из CoreInfoProvider.coreInfo.privacyPolicy
```

### Документация для Блока 8

**Файл:** `docs/flutter/profile.md`

Содержит:
- Что видит авторизованный пользователь vs неавторизованный
- Управление push-уведомлениями: какие категории, как они синхронизируются
- `updateNotificationPreferences` — когда вызывается и что отправляет на сервер
- Контакты ресторана: что статично, что приходит с API

---

## Блок 9 — Polish: Version Check + Error States
**Разработчик:** Архат
**Ветка:** `feature/polish-version-errors`
**Зависимости:** Блок 4 (CoreRepository), все блоки контента (5–8)

### Тикет 9.1 — App version check в SplashScreen

**Файл:** `lib/screens/splash_screen.dart`

После splash-задержки (3200 мс): вызов `CoreRepository().fetchAppVersion(Platform.isIOS ? 'ios' : 'android')`. Сравнить `minVersion` с текущей (const `kAppVersion = '1.0.0'` в `lib/core/theme.dart`).

Сравнение по `major.minor.patch` как три int. Логика:
- `текущая < min` → неотклоняемый `AlertDialog` → `launchUrl(storeUrl)`
- `min ≤ текущая < latest` → отклоняемый баннер

### Тикет 9.2 — Error handling + loading states

**Файлы:** `lib/providers/menu_provider.dart`, `lib/providers/events_provider.dart`, `lib/providers/core_info_provider.dart`, `lib/providers/booking_provider.dart`

Стандартизировать: `error` — `String?` (читаемое RU сообщение). Добавить `retry()`.

Catch `DioException`:
- `connectionTimeout / receiveTimeout` → `'Нет соединения'`
- 5xx → `'Сервер временно недоступен'`
- 4xx → поле `message` из JSON или generic

На каждом экране: error widget с тотем-иконкой + кнопка "Попробовать снова".

---

### Тесты для Блока 9

**Файлы:** `test/screens/splash_screen_test.dart`, `test/providers/error_handling_test.dart`

```
splash_screen_test.dart:
  ✓ Если текущая версия < minVersion → AlertDialog показан
  ✓ AlertDialog не имеет кнопки закрытия (неотклоняемый)
  ✓ Если версия актуальная → нет диалога

error_handling_test.dart:
  ✓ DioException connectionTimeout → error = 'Нет соединения'
  ✓ DioException 503 → error = 'Сервер временно недоступен'
  ✓ retry() сбрасывает error и повторяет запрос
  ✓ MenuProvider: при ошибке сохраняет stale данные
```

### Документация для Блока 9

**Файл:** `docs/flutter/api_client.md` (дополнение)

Добавить раздел:
- Стандартные тексты ошибок (таблица: причина → текст)
- `retry()` pattern: как использовать в новых экранах
- Как работает version check и где задаётся `kAppVersion`
- Как добавить force-update при релизе новой версии

---

## Сводная таблица тикетов

| Блок | Ветка | Разработчик | Тикеты | Зависит от |
|---|---|---|---|---|
| 1 | `feature/infra-api-client` | Архат | 1.1, 1.2 | — |
| 2 | `feature/data-models-auth` | Шерхан | 2.1, 2.2 | Блок 1 |
| 3 | `feature/nav-auth-screens` | Архат | 3.1, 3.2 | Блок 2 |
| 4 | `feature/core-info-fcm` | Шерхан | 4.1, 4.2 | Блок 1, 2 |
| 5 | `feature/menu-integration` | Архат | 5.1, 5.2 | Блок 1, 2 |
| 6 | `feature/events-integration` | Шерхан | 6.1, 6.2, 6.3 | Блок 1, 2, 3, 4 |
| 7 | `feature/booking-integration` | Архат | 7.1, 7.2, 7.3 | Блок 2, 3, 4 |
| 8 | `feature/profile-integration` | Шерхан | 8.1 | Блок 2, 4, 7 |
| 9 | `feature/polish-version-errors` | Архат | 9.1, 9.2 | Блок 4–8 |

---

## Sprint Timeline

```
Sprint 0 (дни 1–3)
  Архат:  Блок 1 (infra-api-client)
  Шерхан: ожидает Блок 1

Sprint 1 (дни 4–7)  — ПАРАЛЛЕЛЬНО
  Архат:  Блок 2 уже готов от Шерхана (B-02) → начинает Блок 3 (nav-auth-screens)
  Шерхан: Блок 2 (data-models-auth)

  * Шерхан начинает Блок 2 сразу после Блока 1 (Архат мёрджит в main)

Sprint 2 (дни 8–12) — ПАРАЛЛЕЛЬНО
  Архат:  Блок 5 (menu-integration)
  Шерхан: Блок 4 (core-info-fcm)

Sprint 3 (дни 13–17) — ПАРАЛЛЕЛЬНО
  Архат:  Блок 7 (booking-integration)
  Шерхан: Блок 6 (events-integration)

Sprint 4 (дни 18–20) — ПАРАЛЛЕЛЬНО
  Шерхан: Блок 8 (profile-integration)
  Архат:  Блок 9 старт (version check)

Sprint 5 (день 21–22)
  Архат:  Блок 9 завершение (error handling)
```

---

## Verification

### После Блока 1
```bash
flutter pub get   # завершается без ошибок
flutter analyze   # 0 ошибок
flutter run       # UI идентичен текущему (мок-данные)
```

### После Блока 3
- Таб 2 → InteriorScreen (заглушка)
- Таб 3 → EventsScreen
- "Забронировать" → push BookingScreen (не меняет таб)
- Profile "НАЧАТЬ ПУТЬ" → PhoneEntryScreen

### После Блоков 5 + 6
```bash
cd backend && docker compose up -d
```
- Меню: категории и блюда из API, видео воспроизводится
- События: реальный список, регистрация требует входа

### После Блоков 7 + 8
- Бронирование: форма отправляется, push "Заявка принята" приходит
- Профиль: имя/телефон из API, toggles синхронизируются

### После Блока 9
- Запуск устаревшей версии → неотклоняемый диалог
- Отсутствие сети → error state + "Попробовать снова"

### Backend Docs
```
http://localhost:8000/api/docs/    # Swagger
http://localhost:8000/api/redoc/   # ReDoc
```

### Запуск тестов
```bash
flutter test                        # все тесты
flutter test test/data/             # только unit tests
flutter test test/screens/          # только widget tests
flutter test --coverage             # с покрытием
genhtml coverage/lcov.info -o coverage/html  # HTML отчёт
```

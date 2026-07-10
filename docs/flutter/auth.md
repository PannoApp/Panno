# Авторизация (Блок 2)

HTTP-слой: [DioClient](api_client.md) (`lib/data/services/api_client.dart`), токены: `TokenStorage` (`lib/data/services/token_storage.dart`).

## Поток авторизации

1. **requestSms** — `POST /users/auth/request-sms/` с телефоном.
2. **verifySms** — `POST /users/auth/verify-sms/` с `phone` и `otp`; ответ: `access`, `refresh`, `is_new_user`.
3. **save tokens** — `TokenStorage.saveTokens(access, refresh)`.
4. **load profile** — `GET /users/profile/` → `UserProfile` в `AuthProvider.currentUser`.

Выход: `POST /auth/logout/` с `refresh`, затем очистка `TokenStorage` и `currentUser`.

## AuthProvider

| Метод | Описание |
|--------|----------|
| `init()` | Читает access token; при наличии загружает профиль |
| `sendOtp(phone)` | Запрос SMS-кода |
| `confirmOtp(phone, code)` | Проверка кода, сохранение токенов, загрузка профиля |
| `logout()` | Logout на сервере + очистка локальной сессии |
| `updateNotificationPreferences(...)` | `PATCH /users/profile/` (категории + `notifications_enabled`) |
| `isLoggedIn` | `currentUser != null` |
| `isNewUser` | `true` после verify-sms для нового пользователя (онбординг — А-4) |
| `eventsCount` | число записей на мероприятия (`GET /events/reservations/my/`) |
| `clearNewUserFlag()` | сброс `isNewUser` после онбординга |

Состояние: `currentUser`, `isLoading`, `error`.

Свойство `user` (`HeroUser`) — мост для экранов: имя, телефон, `journeyStartLabel` (из `date_joined`), `eventsCount`.

### UserProfile (Ш-3)

| Поле | JSON | Описание |
|------|------|----------|
| `notificationsEnabled` | `notifications_enabled` | Мастер-переключатель push (по умолчанию `true`) |
| `dateJoined` | `date_joined` | Дата регистрации → «С нами: Март 2024» |

`EventReservationRepository.fetchMyReservationsCount()` — длина `results` из `/events/reservations/my/`.

## Auth Guard

Используйте `guardAuth(context)` из `lib/core/auth_guard.dart` перед действиями, требующими входа (бронь, закрытые события, «Начать путь»). При отсутствии сессии открывается `PhoneEntryScreen` (SMS OTP).

## Модели данных

### ApiDish
| Поле | Тип | Nullable |
|------|-----|----------|
| id | int | |
| name | String | |
| description | String | |
| price | int | (строка из API → int) |
| category | int | |
| tags | List\<String\> | |
| allergens | List\<String\> | |
| imageUrl | String? | да |
| videoUrl | String? | да |
| weight | String | |
| story | String | |
| isActive | bool | |

### ApiCategory
`id` int, `name` String, `slug` String

### ApiEvent
`id`, `title`, `description`, `startsAt` DateTime, `format` open|closed, `coverUrl?`, `priceFrom?` int, `isPast` bool

### ApiBooking
`id`, `guestName`, `phone`, `date`, `time`, `guestsCount`, `zone?`, `comment?`, `status`

### BookingRequest
`guestName`, `phone`, `date`, `time`, `guestsCount`, `zone?`, `comment?` — только `toJson()`.

### UserProfile
`id`, `phone`, `firstName`, `lastName`, `gender`, `email`, `birthday`, `notifyEvents`, `notifyPromotions`, `notifyClosedEvents`

Файл: `lib/data/models/user_profile.dart`. `gender` — enum `UserGender`
(`male`/`female`/`notSpecified`, JSON: `male`/`female`/`not_specified`),
`birthday` — `DateTime?`, сериализуется в `YYYY-MM-DD` (`formatDateOnly`).
Бэкенд (`GET`/`PATCH /users/profile/`) отдаёт и принимает эти три поля — см.
`backend/docs/users.md#модель-user`. Значения пушатся в CRM Remarked при
каждом успешном `PATCH` (см.
`backend/docs/users.md#remarked--источник-истины-о-госте`).

### CoreInfo
`address`, `workingHours`, `isOpenNow`, `phone`, `socialLinks`, `heroSlides`, `heroVideoUrl?`, `visitRules`, `privacyPolicy`

### InteriorSlide
`id`, `zone`, `zoneDisplay`, `imageUrl`, `caption?`, `order`

Новости афиши: `PiligrimNewsPost` в `lib/data/events_news_data.dart` (не дублировать).

## Пример BookingRequest.toJson()

```dart
const BookingRequest(
  guestName: 'Айдар',
  phone: '+77001234567',
  date: '2026-05-20',
  time: '19:30',
  guestsCount: 4,
).toJson();
// → { guest_name, phone, date, time, guests_count } — без zone/comment, если null
```

## OnboardingScreen (А-4, «Начало пути»)

**Файл:** `lib/screens/onboarding_screen.dart`

Открывается после `verifySms`, когда `AuthProvider.isNewUser == true` (см.
`isNewUser`/`clearNewUserFlag()` в таблице `AuthProvider` выше). Один экран,
без степпера.

**Поля:**
- Имя (`_firstNameCtrl`), фамилия (`_lastNameCtrl`), email (`_emailCtrl`) —
  все три необязательны.
- Дата рождения — `showDatePicker` через `_pickBirthday()`, необязательна.
- Телефон показан read-only (`_PhoneReadOnly`), из `AuthProvider.currentUser.phone`.
- **Пол — единственное обязательное поле** для основного пути (два чипа
  `_GenderOption`: «Мужской»/«Женский», `_selectGender()`). Remarked принимает
  только `male`/`female` (не `not_specified`) — поэтому именно пол, а не имя,
  выбран обязательным полем на этом экране.

**Кнопка «НАЧАТЬ ПУТЬ»** (`_onStart()`): если пол не выбран — показывает
инлайн-ошибку (`_showGenderError`) и не отправляет форму. Если выбран —
вызывает `AuthProvider.updateDisplayProfile(firstName:, lastName:, gender:,
email:, birthday:)` (→ `PATCH /users/profile/`, откуда бэкенд асинхронно
пушит гостя в Remarked — см. `backend/docs/users.md`), затем
`Navigator.pop()`. Ошибка сети не блокирует выход с экрана (try/catch с
пустым телом).

**Ссылка «Пропустить»** (`_onSkip()`): не сохраняет вообще ничего, просто
закрывает экран. Пол остаётся `not_specified` — гость **не** будет создан в
Remarked, пока пол не будет выбран через этот экран повторно (доступен снова
из профиля) или другой PATCH с явным полом.

## TODO

- Регистрация FCM-токена после появления `FcmService` (см. комментарий в `AuthProvider.confirmOtp`).

---

# Навигация и Auth Guard (Блок 3)

## Навигационная схема (5 табов)

| Индекс | Экран | Файл |
|--------|-------|------|
| 0 | HomeScreen | `lib/screens/home_screen.dart` |
| 1 | MenuScreen | `lib/screens/menu_screen.dart` |
| 2 | InteriorScreen | `lib/screens/interior_screen.dart` |
| 3 | EventsScreen | `lib/screens/events_screen.dart` |
| 4 | ProfileScreen | `lib/screens/profile_screen.dart` |

**BookingScreen** не является табом — открывается через `Navigator.push` из кнопки «Забронировать стол» в `HomeActionBlock`. Константа `kNavOpenBooking` (`-1`) в `home_data.dart` остаётся для сценариев вне нижних табов при необходимости.

## PhoneEntryScreen

**Файл:** `lib/screens/phone_entry_screen.dart`

Один экран с двумя состояниями, управляемыми флагом `_awaitingCode`:

1. **Ввод телефона** — поле `+7 7XX XXX XX XX`, валидация: strip non-digits → нужно ≥ 11 цифр. Кнопка «Получить код» → `AuthProvider.sendOtp(phone)`.
2. **Ввод кода** — числовое поле `maxLength: 6`. Кнопка «Подтвердить» → `AuthProvider.confirmOtp(phone, code)` → `Navigator.pop()` при успехе.

Параметров нет. Всегда открывается через `Navigator.push` (не роут в `IndexedStack`).

## Auth Guard

**Файл:** `lib/core/auth_guard.dart`

```dart
// Использование перед любым защищённым действием:
if (!await guardAuth(context)) return;
// продолжить действие — пользователь точно авторизован
```

`guardAuth` проверяет `AuthProvider.isLoggedIn`. Если `false` — открывает `PhoneEntryScreen` через push и ждёт возврата. Возвращает `true` только если после закрытия экрана `isLoggedIn == true`.

## Как добавить экран, требующий авторизации

1. В обработчике нажатия (кнопка / таб) вызвать `guardAuth`:
   ```dart
   onTap: () async {
     if (!await guardAuth(context)) return;
     if (!context.mounted) return;
     // логика после авторизации
   }
   ```
2. Не добавлять `PhoneEntryScreen` в `IndexedStack` — он всегда открывается через push.
3. Не хранить состояние «нужна авторизация» в виджете — `AuthProvider.isLoggedIn` — единственный источник истины.

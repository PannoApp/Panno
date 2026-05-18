# Авторизация (Блок 2)

## Поток авторизации

1. **requestSms** — `POST /auth/request-sms/` с телефоном.
2. **verifySms** — `POST /auth/verify-sms/` с телефоном и кодом; ответ: `access`, `refresh`, `is_new_user`.
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
| `updateNotificationPreferences(...)` | `PATCH /users/profile/` |
| `isLoggedIn` | `currentUser != null` |

Состояние: `currentUser`, `isLoading`, `error`.

Свойство `user` (`HeroUser`) — мост для существующих экранов (профиль, бронь).

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
`id`, `phone`, `firstName`, `lastName`, `notifyEvents`, `notifyPromotions`, `notifyClosedEvents`

### CoreInfo
`address`, `workingHours`, `isOpenNow`, `phone`, `socialLinks`, `heroSlides`, `heroVideoUrl?`, `bookingDepositRequired`, `visitRules`, `privacyPolicy`

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

## TODO

- Регистрация FCM-токена после появления `FcmService` (см. комментарий в `AuthProvider.confirmOtp`).

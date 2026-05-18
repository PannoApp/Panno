# Push-уведомления (FCM)

## Поток

1. `Firebase.initializeApp` в `main()`.
2. `FcmService.instance.init()` — permission, listeners.
3. После входа: `POST /notifications/device/register/` с `{ "fcm_token": "..." }` (JWT обязателен).
4. При обновлении токена Firebase — повторная регистрация (`onTokenRefresh`).

Реализация: `lib/data/services/fcm_service.dart`.

## Категории (настройки профиля)

Соответствуют полям `UserProfile`:

- `notify_events` — афиша / события
- `notify_promotions` — акции
- `notify_closed_events` — закрытые мероприятия

## Foreground

`FirebaseMessaging.onMessage` → SnackBar (фон `PiligrimColors.earthDeep`, текст `PiligrimColors.sky`).

## Навигация по tap

Поле `data['type']` в payload:

| type | Действие |
|------|----------|
| `event` | таб «Афиша» (индекс 3) |
| `booking` | `Navigator.push(BookingScreen)` |

Обработчик: `PushNavigationHandler` в `lib/core/push_navigation.dart`, регистрация в `RootShell`.

## Локальное тестирование

1. `flutterfire configure` + реальные `google-services.json` / `GoogleService-Info.plist`.
2. Войти в приложение (JWT).
3. Firebase Console → Cloud Messaging → Send test message на FCM token устройства.

## Ограничения бэкенда

Маркетинговые пуши: не более 3 в неделю, окно 09:00–21:00 (Asia/Almaty). Сервисные (бронь) — без лимита.

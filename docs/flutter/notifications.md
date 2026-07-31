# Push-уведомления (FCM)

## Поток

Инициализация не блокирует первый кадр (splash) и разнесена на несколько шагов:

1. `PiligrimApp.initState()` планирует `bootstrapFirebase()` через `WidgetsBinding.instance.addPostFrameCallback` — т.е. запускается только после первого отрисованного кадра, а не в `main()`.
2. `bootstrapFirebase()` (`lib/main.dart`):
   - если `!DefaultFirebaseOptions.isConfigured` (нет реального `google-services.json` / `GoogleService-Info.plist`, только заглушка) — выходит сразу, пуши остаются выключены;
   - иначе `Firebase.initializeApp(...)` с таймаутом 15 сек;
   - `FcmService.instance.initEarly(navigatorKey: rootNavigatorKey)` с таймаутом 5 сек — регистрирует слушатели **без** системного диалога разрешений: `onMessage`, `onMessageOpenedApp`, разбор cold-start `getInitialMessage()` (таймаут 2 сек) и подписка на `onTokenRefresh`;
   - `FcmService.instance.requestPermissionIfNeeded()` — отдельно вызывает `messaging.requestPermission()` (системный диалог), уже после того как UI отрисован;
   - любой `TimeoutException` или другая ошибка на этих шагах — просто логируется (`debugPrint`), приложение продолжает работать без FCM.
3. Регистрация токена на бэкенде — **не** часть `FcmService.init*`, её вызывает `AuthProvider` (`lib/providers/auth_provider.dart`, `_registerFcmIfPossible()`) после успешного восстановления сессии и после логина: `POST /notifications/device/register/` с `{ "fcm_token": "..." }` (JWT обязателен). Ошибки регистрации проглатываются — FCM опционален, пока Firebase не настроен полностью.
4. При обновлении токена Firebase — повторная регистрация напрямую из `initEarly()` (`messaging.onTokenRefresh.listen(...)` → `registerTokenWithServer`), без участия `AuthProvider`.

Реализация: `lib/data/services/fcm_service.dart` (`initEarly`, `requestPermissionIfNeeded`, `init` — обёртка над первыми двумя для тестов), `lib/main.dart` (`bootstrapFirebase`).

## Категории (настройки профиля)

Соответствуют полям `UserProfile`, переключаются в `ProfileScreen` (`_handleNotifToggle`) через `AuthProvider.updateNotificationPreferences(...)`:

| id в UI | Поле `UserProfile` | Назначение |
|---------|---------------------|------------|
| `events` | `notifyEvents` (`notify_events`) | афиша / события |
| `promo` | `notifyPromotions` (`notify_promotions`) | акции |
| `private` | `notifyClosedEvents` (`notify_closed_events`) | закрытые мероприятия |
| `global` | `notificationsEnabled` (`notifications_enabled`) | общий выключатель — при включении/выключении также проставляет `events`/`promotions`/`closedEvents` в то же значение |

## Foreground

`FirebaseMessaging.onMessage` → SnackBar (фон `PiligrimColors.earthDeep`, текст `PiligrimColors.sky`).

## Навигация по tap

Поле `data['type']` в payload:

| type | Действие |
|------|----------|
| `event` | таб «Афиша» (индекс 3) |
| `booking` | `Navigator.push(BookingScreen)` |

`lib/core/push_navigation.dart` содержит только статический callback `PushNavigationHandler.onPushType` — реальная логика навигации (`switch` по `type`) находится в `RootShell._onPushType` (`lib/main.dart`), которая подписывается на этот callback в `initState()` и отписывается в `dispose()`. Если `RootShell` ещё не смонтирован (пуш открыт до входа в приложение), `onPushType` равен `null` и навигация просто не срабатывает.

## Локальное тестирование

1. `flutterfire configure` + реальные `google-services.json` / `GoogleService-Info.plist`.
2. Войти в приложение (JWT).
3. Firebase Console → Cloud Messaging → Send test message на FCM token устройства.

## Ограничения бэкенда

Маркетинговые пуши: не более 3 в неделю, окно 09:00–21:00 (Asia/Almaty). Сервисные (бронь) — без лимита.

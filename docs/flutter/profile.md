# Блок 8: Профиль и контакты

Экран «Карта Героя» (`ProfileScreen`) показывает данные пользователя, настройки push-уведомлений и контакты ресторана. Данные приходят из `AuthProvider`, `CoreInfoProvider` и `BookingProvider`.

---

## Авторизованный vs гость

| Состояние | Шапка | Уведомления | Выход |
|---|---|---|---|
| Гость (`isLoggedIn == false`) | «Герой без имени», кнопка **НАЧАТЬ ПУТЬ** → `PhoneEntryScreen` через `guardAuth` | Текст «Войдите, чтобы управлять уведомлениями» | Скрыт |
| Вход выполнен | Имя и телефон из `AuthProvider.currentUser` / `user` (`HeroUser`) | Три переключателя из профиля API | Кнопка «Выйти» |

Счётчик **Бронирований** в статистике — `BookingProvider.history.length`. При открытии экрана, если пользователь авторизован, вызывается `BookingProvider.loadHistory()`.

---

## Push-уведомления

Помимо трёх категорий ниже, в карточке `_NotificationsCard` есть главный переключатель **«Уведомления»** (UI id `global`), который отражает мастер-флаг `UserProfile.notificationsEnabled` (`notifications_enabled` на сервере — см. `backend/docs/users.md`). Он рисуется первым, до категорий, с разделителем `_ProfileHairlineDivider`.

Категории (UI в `kNotifCategories`, `lib/core/profile_data.dart`):

| UI id | Поле API | Описание |
|---|---|---|
| `global` | `notifications_enabled` | Уведомления (мастер-переключатель — вкл/выкл все push разом) |
| `events` | `notify_events` | Мероприятия |
| `promo` | `notify_promotions` | Акции |
| `private` | `notify_closed_events` | Закрытые события |

Переключение вызывает `AuthProvider.updateNotificationPreferences(...)`, который отправляет **PATCH** `/users/profile/` только с изменёнными полями и обновляет `currentUser` ответом сервера. Переключение `global` — особый случай: `_handleNotifToggle` (см. `profile_screen.dart`) шлёт `notificationsEnabled` **и** все три категории тем же значением, что фактически включает/выключает всё разом одним запросом.

Реализация HTTP — [lib/data/repositories/profile_repository.dart](../../lib/data/repositories/profile_repository.dart).

---

## Удаление аккаунта

Карточка `_AccountSessionCard` объединяет «Выйти из аккаунта» и «Удалить аккаунт» в одном glass-блоке (нижняя часть экрана, только для авторизованных).

1. Тап по «Удалить аккаунт» → `_confirmDeleteAccount()` → `showPiligrimDeleteAccountDialog(context)` ([lib/widgets/piligrim_delete_account_dialog.dart](../../lib/widgets/piligrim_delete_account_dialog.dart)) — модалка с текстом «Профиль, бронирования и уведомления будут удалены без возможности восстановления» и двумя кнопками: **«Оставить аккаунт»** (закрывает диалог, `pop(false)`) и **«Удалить аккаунт»** (`pop(true)`).
2. Если пользователь подтвердил (`confirmed == true`), вызывается `AuthProvider.deleteAccount()`.
3. `AuthProvider.deleteAccount()` → `AuthService.deleteAccount()` → **DELETE** `/users/account/` (см. [lib/data/services/auth_service.dart](../../lib/data/services/auth_service.dart)). При успехе локально очищаются токены (`TokenStorage.clearTokens()`), `currentUser = null`, `eventsCount = 0`.
4. Поскольку `AuthProvider.isLoggedIn` вычисляется как `currentUser != null`, `Consumer<AuthProvider>` в `ProfileScreen` автоматически перерисовывается в гостевое состояние (`PiligrimAuthView`) — явной навигации не требуется.
5. При ошибке — `PiligrimToast` с сообщением из `AuthProvider.error` (или дефолтным «Не удалось удалить аккаунт»), диалог не открывается повторно, аккаунт остаётся как есть.

---

## Мои мероприятия (история бронирований событий)

Карточка статистики «Мероприятия» (вторая в `_StatsRow`, значение — `user.eventsCount`) при тапе открывает `EventReservationHistoryScreen` ([lib/screens/event_reservation_history_screen.dart](../../lib/screens/event_reservation_history_screen.dart)).

Экран в `initState()` вызывает `EventsProvider.loadMyReservations()` → **GET** `/events/reservations/my/` (см. `lib/data/repositories/event_reservation_repository.dart`) и показывает список бронирований мероприятий текущего пользователя (`ApiEventReservation`). Pull-to-refresh / повтор после ошибки вызывает тот же `loadMyReservations()`.

---

## Контакты и правила

| Блок | Источник |
|---|---|
| Адрес, телефон, мессенджеры | `CoreInfoProvider.coreInfo` (`social_links` / legacy `whatsapp`, `telegram`, `instagram`) |
| Часы работы | `CoreInfoProvider` (`_HoursCard`) |
| Правила посещения | `coreInfo.visitRules`; если пусто — fallback `kVisitRules` |
| Политика конфиденциальности | `coreInfo.privacyPolicy`; иначе `https://piligrim.kz/privacy` |
| Пользовательское соглашение, обратная связь | Статические URL в UI |

---

## Связанные файлы

- [lib/screens/profile_screen.dart](../../lib/screens/profile_screen.dart)
- [lib/providers/auth_provider.dart](../../lib/providers/auth_provider.dart)
- [lib/data/repositories/profile_repository.dart](../../lib/data/repositories/profile_repository.dart)
- [lib/data/services/auth_service.dart](../../lib/data/services/auth_service.dart) — HTTP-вызов удаления аккаунта
- [lib/widgets/piligrim_delete_account_dialog.dart](../../lib/widgets/piligrim_delete_account_dialog.dart) — диалог подтверждения удаления
- [lib/screens/event_reservation_history_screen.dart](../../lib/screens/event_reservation_history_screen.dart) — «Мои мероприятия»
- Тесты: `test/data/repositories/profile_repository_test.dart`, `test/screens/profile_screen_test.dart`

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

Категории (UI в `kNotifCategories`, `lib/core/profile_data.dart`):

| UI id | Поле API | Описание |
|---|---|---|
| `events` | `notify_events` | Мероприятия |
| `promo` | `notify_promotions` | Акции |
| `private` | `notify_closed_events` | Закрытые события |

Переключение вызывает `AuthProvider.updateNotificationPreferences(...)`, который отправляет **PATCH** `/users/profile/` только с изменёнными полями и обновляет `currentUser` ответом сервера.

Реализация HTTP — [lib/data/repositories/profile_repository.dart](../../lib/data/repositories/profile_repository.dart).

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
- Тесты: `test/data/repositories/profile_repository_test.dart`, `test/screens/profile_screen_test.dart`

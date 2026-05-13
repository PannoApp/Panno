# Модуль: notifications

Отвечает за регистрацию мобильных устройств и отправку FCM push-уведомлений.

## Как работает FCM в проекте

```
1. Пользователь открывает приложение
        ↓
2. Firebase SDK на телефоне выдаёт FCM-токен (уникальный ID устройства)
        ↓
3. Приложение отправляет токен на бэкенд
   POST /api/v1/notifications/device/register/
        ↓
4. Бэкенд сохраняет токен в таблицу UserDevice (привязан к пользователю)
        ↓
5. Когда нужно отправить push — Celery-задача берёт токены пользователя из БД
        ↓
6. Запрос к Firebase API → Firebase доставляет уведомление на телефон
```

## Эндпоинт

### POST /api/v1/notifications/device/register/

Регистрирует или обновляет FCM-токен устройства.

**Авторизация:** Bearer JWT (обязательна)

**Когда вызывать:**
- При каждом входе пользователя в приложение
- При обновлении FCM-токена Firebase (токен может обновиться)
- При смене аккаунта на устройстве

**Тело запроса:**
```json
{ "fcm_token": "dGhpcyBpcyBhIHNhbXBsZSBmY20gdG9rZW4..." }
```

**Ответ 201** — токен зарегистрирован впервые:
```json
{ "message": "Устройство успешно зарегистрировано." }
```

**Ответ 200** — токен уже существовал, перепривязан к текущему пользователю:
```json
{ "message": "Токен устройства обновлен (перепривязан)." }
```

**Ответ 400** — токен не передан:
```json
{ "fcm_token": ["Обязательное поле."] }
```

## Celery-задача: send_push_notification

Файл: `apps/notifications/tasks.py`

Отправляет push-уведомление конкретному пользователю на **все** его зарегистрированные устройства.

### Retry-политика

Все Celery-таски в модуле (`send_push_notification`, `send_bulk_push_notification`) настроены на автоматический retry:

| Параметр | Значение | Описание |
|---|---|---|
| `autoretry_for` | `(Exception,)` | Retry при любом исключении (сбой Firebase, БД, сети) |
| `max_retries` | `3` | Максимум 3 повторные попытки |
| `default_retry_delay` | `60` | Пауза между попытками — 60 секунд |
| `acks_late` | `True` | Сообщение удаляется из очереди только после успешного завершения; если worker упал — задача вернётся в очередь |

Ранние выходы из задачи (`return` без исключения — например, пользователь отключил категорию, нет устройств) **не** триггерят retry — это штатное завершение, не ошибка.

**Сигнатура:**
```python
send_push_notification.delay(
    user_id=42,
    title="Бронирование подтверждено",
    body="Ваш столик забронирован. Ждём вас!",
    data={"booking_id": "7", "status": "confirmed"},  # необязательно
    category="events"  # необязательно
)
```

| Параметр | Тип | Описание |
|---|---|---|
| `user_id` | int | ID пользователя из таблицы User |
| `title` | string | Заголовок уведомления |
| `body` | string | Текст уведомления |
| `data` | dict | Дополнительные данные для приложения (необязательно) |
| `category` | string | Категория уведомления для проверки настроек пользователя (необязательно) |

### Категории уведомлений

| `category` | Флаг на модели User | Описание |
|---|---|---|
| `events` | `notify_events` | Мероприятия и афиша |
| `promotions` | `notify_promotions` | Акции и специальные предложения |
| `closed_events` | `notify_closed_events` | Закрытые/VIP события |
| *(не передаётся)* | — | Сервисные уведомления (бронь) — всегда доставляются |

Пуш не отправляется если `category` задан и:
- `user.notifications_enabled = False` — пользователь глобально отключил все уведомления, **или**
- соответствующий флаг категории (`notify_events` / `notify_promotions` / `notify_closed_events`) = `False`

Сервисные пуши (`category=None`) — обязательные. Не блокируются ни одним из флагов.

**Что делает задача:**
1. Берёт все FCM-токены пользователя из `UserDevice`
2. Отправляет `MulticastMessage` в Firebase (один запрос на все устройства)
3. Если Firebase вернул ошибку для конкретного токена — удаляет его из БД (токен устарел)
4. Логирует результат

## Где вызывается задача

| Событие | Категория | Триггер | Файл |
|---|---|---|---|
| Создание брони (статус `pending`) | — (сервисное) | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Статус бронирования → `confirmed` | — (сервисное) | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Статус бронирования → `canceled` | — (сервисное) | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Статус бронирования → `completed` | — (сервисное) | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Напоминание за 1–2 ч до визита | — (сервисное) | Celery Beat (каждые 15 мин) | `apps/bookings/tasks.py` |
| Создана запись на мероприятие | `events` | Django-сигнал `post_save` на `EventReservation` | `apps/events/signals.py` |

## Модель UserDevice

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `user` | FK → User | Владелец устройства |
| `fcm_token` | string | Токен FCM (уникальный, до 4096 символов) |
| `created_at` | datetime | Дата регистрации |
| `updated_at` | datetime | Дата последнего обновления |

`fcm_token` уникален глобально — один токен принадлежит одному устройству. При смене аккаунта токен перепривязывается к новому пользователю.

## Инициализация Firebase

При старте Django (`apps.py → ready()`) происходит инициализация Firebase Admin SDK:

```python
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
if cred_path and os.path.exists(cred_path):
    firebase_admin.initialize_app(credentials.Certificate(cred_path))
```

В `.env` путь к credentials-файлу:
```
FIREBASE_CREDENTIALS_PATH=/app/backend/firebase-credentials.json
```

- **В Docker:** путь `/app/backend/firebase-credentials.json` существует — Firebase работает.
- **Локально (вне Docker):** путь не существует — Firebase не инициализируется, пуши не уходят. В консоль выводится предупреждение. Это ожидаемое поведение.

## Массовая рассылка

### POST /api/v1/notifications/bulk-push/

Ставит в очередь push-рассылку выбранному сегменту пользователей.

**Авторизация:** Bearer JWT, только `role=content_manager` или `role=admin`

**Тело запроса:**
```json
{
  "title": "Специальное предложение",
  "body": "Скидка 20% на все блюда в пятницу!",
  "data": {"promo_id": "42"},
  "category": "promotions",
  "segment": "all"
}
```

| Параметр | Обязательное | Описание |
|---|---|---|
| `title` | Да | Заголовок уведомления |
| `body` | Да | Текст уведомления |
| `data` | Нет | Дополнительные данные (словарь строк) |
| `category` | Нет | `events` / `promotions` / `closed_events` — проверяет флаги пользователя |
| `segment` | Да | Сегмент аудитории (см. ниже) |
| `last_visit_days` | Для `last_visit_days` | Количество дней |
| `event_id` | Для `participated_in_event` | ID мероприятия |
| `registered_after` | Для `registered_after` | Дата `YYYY-MM-DD` |
| `city` | Для `by_city` | Название города (точное совпадение, например `"Алматы"`) |

### Сегменты

| `segment` | Аудитория |
|---|---|
| `all` | Все пользователи с зарегистрированными FCM-устройствами |
| `last_visit_days` | Пользователи, у которых есть бронирование со статусом `completed` за последние N дней |
| `participated_in_event` | Участники конкретного мероприятия (`event_id`) |
| `registered_after` | Пользователи, зарегистрированные после указанной даты |
| `by_city` | Пользователи с конкретным городом (`city`) — по геолокации, сохранённой в профиле |

**Ответ 202:**
```json
{ "queued": 142, "segment": "all" }
```

Рассылка выполняется асинхронно через Celery: одна задача `send_bulk_push_notification` → N задач `send_push_notification`.

## Статистика кампаний (PushCampaign)

Каждый вызов `POST /api/v1/notifications/bulk-push/` создаёт запись `PushCampaign` в базе данных. Статистика доступна в Django-админке: `Notifications → Push-кампании`.

| Поле | Описание |
|---|---|
| `created_at` | Дата и время запуска рассылки |
| `title` | Заголовок уведомления |
| `body` | Текст уведомления |
| `category` | Категория (`events`, `promotions`, `closed_events` или пустая) |
| `segment` | Сегмент аудитории |
| `total_users` | Кол-во пользователей, которым поставлена задача отправки |
| `delivered_count` | Успешно доставлено (по ответу FCM) — накапливается асинхронно |
| `failed_count` | Ошибок доставки — накапливается асинхронно |

`delivered_count` и `failed_count` обновляются при выполнении каждой задачи `send_push_notification` через `F()` выражение — атомарно, без гонок. Редактировать/удалять кампании через Admin нельзя (только суперпользователь может удалить).

## Лимит рассылки

Маркетинговые пуши (`category != None`) ограничены по частоте и времени суток. Сервисные пуши (бронь, напоминания — `category=None`) ограничений не имеют.

### Недельный лимит

Каждый пользователь может получить не более `PUSH_WEEKLY_LIMIT` маркетинговых пушей в неделю.

| Настройка | Env-переменная | По умолчанию |
|---|---|---|
| `PUSH_WEEKLY_LIMIT` | `PUSH_WEEKLY_LIMIT` | `3` |

**Реализация:** счётчик хранится в Redis под ключом `push_weekly:<user_id>:<iso_week_number>` с TTL 7 дней. При превышении задача завершается без отправки, в лог пишется `Push skipped: weekly limit reached`.

### Временное окно

Маркетинговые пуши отправляются только в допустимое время суток. Если задача запущена вне окна, она откладывается через `apply_async(eta=...)` на начало следующего окна (09:00 следующего дня).

| Настройка | Env-переменная | По умолчанию |
|---|---|---|
| `PUSH_ALLOWED_HOUR_START` | `PUSH_ALLOWED_HOUR_START` | `9` (09:00) |
| `PUSH_ALLOWED_HOUR_END` | `PUSH_ALLOWED_HOUR_END` | `21` (21:00) |

Время сравнивается с локальным временем сервера (`django.utils.timezone.localtime`).

## Файлы модуля

```
apps/notifications/
├── models.py       # UserDevice
├── serializers.py  # UserDeviceSerializer, BulkPushSerializer
├── views.py        # RegisterDeviceView, BulkPushView
├── tasks.py        # send_push_notification, send_bulk_push_notification (Celery)
├── apps.py         # инициализация Firebase в ready()
└── urls.py         # Маршруты /api/v1/notifications/
```

## Важные нюансы

- Один пользователь может иметь несколько устройств — push уйдёт на все.
- Невалидные токены (например, пользователь удалил приложение) автоматически удаляются из БД при первой неудачной отправке.
- Celery должен быть запущен, иначе задачи будут накапливаться в очереди Redis, но не выполняться.
- `data` в уведомлении — это словарь из строк. Если передаёшь числа, нужно явно конвертировать: `str(instance.pk)`.
- Для изменения лимитов достаточно поменять env-переменные и перезапустить worker — код читает настройки из `django.conf.settings` при каждом вызове задачи.

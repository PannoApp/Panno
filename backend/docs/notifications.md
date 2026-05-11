# Модуль: notifications

Отвечает за регистрацию мобильных устройств и отправку FCM push-уведомлений.

## Как работает FCM в проекте

```
1. Пользователь открывает приложение
        ↓
2. Firebase SDK на телефоне выдаёт FCM-токен (уникальный ID устройства)
        ↓
3. Приложение отправляет токен на бэкенд
   POST /api/notifications/device/register/
        ↓
4. Бэкенд сохраняет токен в таблицу UserDevice (привязан к пользователю)
        ↓
5. Когда нужно отправить push — Celery-задача берёт токены пользователя из БД
        ↓
6. Запрос к Firebase API → Firebase доставляет уведомление на телефон
```

## Эндпоинт

### POST /api/notifications/device/register/

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

**Сигнатура:**
```python
send_push_notification.delay(
    user_id=42,
    title="Бронирование подтверждено",
    body="Ваш столик забронирован. Ждём вас!",
    data={"booking_id": "7", "status": "confirmed"}  # необязательно
)
```

| Параметр | Тип | Описание |
|---|---|---|
| `user_id` | int | ID пользователя из таблицы User |
| `title` | string | Заголовок уведомления |
| `body` | string | Текст уведомления |
| `data` | dict | Дополнительные данные для приложения (необязательно) |

**Что делает задача:**
1. Берёт все FCM-токены пользователя из `UserDevice`
2. Отправляет `MulticastMessage` в Firebase (один запрос на все устройства)
3. Если Firebase вернул ошибку для конкретного токена — удаляет его из БД (токен устарел)
4. Логирует результат

## Где вызывается задача

| Событие | Триггер | Файл |
|---|---|---|
| Статус бронирования → `confirmed` | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Статус бронирования → `canceled` | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Статус бронирования → `completed` | Django-сигнал `post_save` на `TableBooking` | `apps/bookings/signals.py` |
| Создана запись на мероприятие | Django-сигнал `post_save` на `EventReservation` | `apps/events/signals.py` |

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

## Файлы модуля

```
apps/notifications/
├── models.py       # UserDevice
├── serializers.py  # UserDeviceSerializer
├── views.py        # RegisterDeviceView
├── tasks.py        # send_push_notification (Celery)
├── apps.py         # инициализация Firebase в ready()
└── urls.py         # Маршруты /api/notifications/
```

## Важные нюансы

- Один пользователь может иметь несколько устройств — push уйдёт на все.
- Невалидные токены (например, пользователь удалил приложение) автоматически удаляются из БД при первой неудачной отправке.
- Celery должен быть запущен, иначе задачи будут накапливаться в очереди Redis, но не выполняться.
- `data` в уведомлении — это словарь из строк. Если передаёшь числа, нужно явно конвертировать: `str(instance.pk)`.

# Тестирование

## Обзор

В проекте 162 unit-теста для всех 6 модулей.

Тесты покрывают:
- Сервисный слой (OTP-логика)
- Сериализаторы (валидация данных)
- API-эндпоинты (HTTP-статусы, тела ответов, права доступа)
- Django-сигналы (push-уведомления при изменении статусов)
- Celery-задачу `send_push_notification` (отправка и очистка невалидных токенов)
- Singleton-модель `RestaurantInfo`

---

## Тестовые настройки

Файл: `config/settings/test.py`

| Компонент | В боевом режиме | В тестах |
|---|---|---|
| База данных | PostgreSQL | SQLite (в памяти) |
| Кэш (OTP, throttle) | Redis | LocMem (в процессе) |
| Celery broker | Redis | Memory (задачи не выполняются) |
| Хранилище файлов | FileSystem / S3 | InMemory (файлы не пишутся на диск) |
| Хеширование паролей | bcrypt | MD5 (быстрее) |

Тесты не требуют запущенного PostgreSQL, Redis или Firebase.

---

## Запуск локально

```bash
# Из директории backend/
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps
```

Дополнительные флаги:

```bash
# Подробный вывод (имя каждого теста)
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps --verbosity=2

# Только один модуль
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps.users

# Только один класс
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps.bookings.tests.BookingSignalTest

# Один конкретный тест
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps.users.tests.SMSServiceTest.test_verify_otp_correct_returns_true_and_deletes_key

# Остановиться на первой ошибке
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps --failfast
```

---

## Запуск в Docker

### Вариант 1 — контейнеры уже запущены

```bash
docker-compose exec backend python manage.py test apps --settings=config.settings.test
```

### Вариант 2 — без запущенных контейнеров (рекомендуется в CI)

```bash
# --no-deps: не запускает зависимые сервисы (db, redis) — тесты их не требуют
# --rm: удалить контейнер после завершения
docker-compose run --rm --no-deps backend \
  python manage.py test apps --settings=config.settings.test
```

### Вариант 3 — с подробным выводом

```bash
docker-compose run --rm --no-deps backend \
  python manage.py test apps --settings=config.settings.test --verbosity=2
```

> **Примечание:** `--no-deps` работает только если образ `backend` уже собран (`docker-compose build backend`).
> Если образ не собран — сначала выполни `docker-compose build backend`.

---

## Структура тестов

### users — 30 тестов

| Класс | Что проверяет |
|---|---|
| `SMSServiceTest` | генерация OTP (4 цифры, диапазон), сохранение в кэш, однократное использование |
| `RequestSMSSerializerTest` | валидация формата номера телефона |
| `VerifySMSSerializerTest` | валидация OTP (ровно 4 цифры, только цифры) |
| `RequestSMSViewTest` | `POST /api/v1/users/auth/request-sms/` — успех, 400, 500 |
| `VerifySMSViewTest` | `POST /api/v1/users/auth/verify-sms/` — JWT-токены, создание нового пользователя, неверный код |
| `UserProfileViewTest` | `GET/PATCH /api/v1/users/profile/` — 401 без токена, read-only поля, PUT запрещён |

### bookings — 48 тестов

| Класс | Что проверяет |
|---|---|
| `TableBookingSerializerTest` | guests_count (0 и 51 — невалидны, 50 — валидно), обязательные поля, read-only статус |
| `TableBookingListCreateViewTest` | пользователь видит только свои брони, создание брони, 401 без токена |
| `BookingSignalTest` | push при `confirmed`/`canceled`/`completed`, нет push при создании, нет push без пользователя, нет push если статус не изменился |
| `SendBookingRemindersTaskTest` | нет броней в окне → 0, push для `confirmed` брони в окне, пропуск `pending` и без пользователя, другая дата → пропуск |
| `TableBookingStaffSerializerTest` | `status` доступен для записи, `user_phone` из связанного User, `user_phone=None` без пользователя, `user` read-only, невалидный статус → ошибка |
| `StaffBookingListViewTest` | `hall_manager` и `admin` получают 200, обычный пользователь → 403, неавторизованный → 401, возвращает брони всех пользователей, `user_phone` и `status` в ответе |
| `StaffBookingUpdateViewTest` | `hall_manager` и `admin` меняют статус → 200, 403/401/404/400/405, смена статуса запускает push, `user_phone` в ответе, поле `user` нельзя изменить |

### events — 25 тестов

| Класс | Что проверяет |
|---|---|
| `UpcomingEventsListViewTest` | только будущие активные события, сортировка по ближайшей дате |
| `ArchivedEventsListViewTest` | только прошедшие активные события |
| `NewsListViewTest` | сортировка от свежей к старой |
| `EventReservationCreateViewTest` | создание, повторная запись → 400, 401 без токена, несуществующий event → 400 |
| `UserEventReservationsListViewTest` | только собственные записи, `event_details` в ответе |
| `EventReservationSerializerTest` | дубликат → ValidationError |
| `EventReservationSignalTest` | push при создании, нет push при обновлении |

### menu — 17 тестов

| Класс | Что проверяет |
|---|---|
| `CategoryListViewTest` | сортировка по `order`, нет пагинации (весь список сразу) |
| `DishListViewTest` | только активные блюда, фильтр по `category_id` и `tag_id`, `page_size` по умолчанию 5, вложенные поля |
| `CategoryModelTest` | `__str__` |
| `DishModelTest` | `__str__`, неактивное блюдо остаётся в БД |

### core — 12 тестов

| Класс | Что проверяет |
|---|---|
| `RestaurantInfoModelTest` | `load()` создаёт запись, `save()` принудительно `pk=1`, `delete()` ничего не делает, вторая запись невозможна |
| `RestaurantInfoViewTest` | `GET /api/v1/core/info/` — публичный доступ, обязательные поля в ответе, nullable поля |

### notifications — 30 тестов

| Класс | Что проверяет |
|---|---|
| `RegisterDeviceViewTest` | регистрация нового → 201, перепривязка существующего токена → 200, 401 без токена, один пользователь — несколько устройств |
| `UserDeviceModelTest` | `__str__`, уникальность `fcm_token` |
| `SendPushNotificationTaskTest` | нет устройств → Firebase не вызывается, отправка на все устройства, удаление невалидных токенов, передача `data`, `data={}` по умолчанию |
| `SendPushNotificationCategoryTest` | пропуск при выключенных `notify_events`/`notify_promotions`/`notify_closed_events`, отправка при `category=None` и неизвестной категории, несуществующий пользователь → пропуск |
| `SendBulkPushNotificationTaskTest` | одна задача на пользователя, пустой список → 0, передача `category` и `data` в подзадачи |
| `BulkPushViewTest` | обычный пользователь → 403, 401 без токена, отсутствие `title` → 400, `segment=all` → 202, корректный подсчёт уникальных пользователей, `participated_in_event` без `event_id` → 400, `registered_after` без даты → 400, `last_visit_days` → 202 |

---

## Паттерны мокирования

### Celery-задача (сигналы)

Сигналы вызывают `send_push_notification.delay(...)`. В тестах мокируется вся задача целиком:

```python
@patch('apps.notifications.tasks.send_push_notification')
def test_push_sent(self, mock_task):
    # ... создать объект, который триггерит сигнал ...
    mock_task.delay.assert_called_once()
    _, kwargs = mock_task.delay.call_args
    self.assertEqual(kwargs['user_id'], user.pk)
```

### Firebase (Celery-задача напрямую)

При тестировании самой задачи `send_push_notification` мокируется модуль `messaging`:

```python
@patch('apps.notifications.tasks.messaging')
def test_sends_to_devices(self, mock_messaging):
    mock_response = MagicMock()
    mock_response.failure_count = 0
    mock_response.success_count = 1
    mock_messaging.send_multicast.return_value = mock_response

    send_push_notification(user_id=..., title='T', body='B')

    # Проверяем аргументы конструктора MulticastMessage
    _, kwargs = mock_messaging.MulticastMessage.call_args
    self.assertIn('my_token', kwargs['tokens'])
```

### OTP (Redis → LocMem)

Тестовые настройки (`config/settings/test.py`) глобально заменяют Redis на LocMem. Нужно только чистить кэш в `setUp`:

```python
def setUp(self):
    cache.clear()
    cache.set('otp_+77001234567', '1234', 180)
```

### Изображения (ImageField)

Для моделей с обязательным `ImageField` (Event, Dish) используется минимальный PNG в памяти:

```python
_PNG = b'\x89PNG\r\n...'  # 1×1 пиксель

def make_image(name='img.png'):
    return SimpleUploadedFile(name, _PNG, content_type='image/png')

Event.objects.create(image=make_image(), ...)
```

Тестовые настройки используют `InMemoryStorage`, поэтому файлы не пишутся на диск.

---

## Что не покрыто тестами

| Что | Почему |
|---|---|
| Throttling (3/min, 5/min) | Проверяется вручную или в интеграционных тестах с Redis |
| Django-админка | Стандартный Django — тесты не нужны |
| Миграции | Проверяются при `manage.py migrate` |
| S3-хранилище | Требует реального MinIO/S3 — выходит за рамки unit-тестов |

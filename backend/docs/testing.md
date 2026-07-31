# Тестирование

## Обзор

В проекте 696 unit-тестов для всех 6 модулей.

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

# Только один класс из пакета tests/ (events и menu разбиты на несколько файлов)
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps.events.tests.test_staff_event_views.StaffEventViewSetTest
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps.menu.tests.test_staff_views.StaffDishViewSetTest

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

> Число тестов ниже получено прогоном `grep -c "def test_" <файл>` по каждому файлу тестов и актуально на момент последнего обновления этого документа. Модули `events` и `menu` больше не однофайловые `tests.py` — тесты разнесены по пакету `tests/` с несколькими файлами (см. ниже).

### users — 121 тест (`apps/users/tests.py`)

Один файл, тесты покрывают OTP-логику, JWT (login/refresh/logout), профиль, троттлинг SMS, синхронизацию `role`↔`is_staff`, а также интеграцию с Remarked (подтягивание данных гостя, пуш профиля в Remarked, обратная синхронизация).

| Класс | Что проверяет |
|---|---|
| `SMSServiceTest` | генерация OTP (4 цифры, диапазон), сохранение в кэш, однократное использование |
| `SendSmsTaskTest` | Celery-задача отправки SMS с кодом |
| `RequestSMSSerializerTest` | валидация формата номера телефона |
| `VerifySMSSerializerTest` | валидация OTP (ровно 4 цифры, только цифры) |
| `RequestSMSViewTest` | `POST /api/v1/users/auth/request-sms/` — успех, 400, 500 |
| `VerifySMSViewTest` | `POST /api/v1/users/auth/verify-sms/` — JWT-токены, создание нового пользователя, неверный код |
| `UserProfileViewTest` | `GET/PATCH /api/v1/users/profile/` — 401 без токена, read-only поля, PUT запрещён |
| `UserProfileSerializerTest` | валидация полей профиля |
| `PhoneSMSThrottleTest` | троттлинг запроса SMS по номеру телефона |
| `RequestSMSPhoneThrottleIntegrationTest` | троттлинг end-to-end через реальный кэш |
| `UserRoleIsStaffSyncTest` | смена `role` автоматически выставляет/снимает `is_staff` |
| `UserAdminIsStaffAutoSetTest` | то же поведение при сохранении через Django Admin |
| `TokenRefreshViewTest` | обновление JWT access-токена |
| `LogoutViewTest` | logout — блэклист refresh-токена |
| `DeleteAccountViewTest` | удаление аккаунта пользователем |
| `JWTSettingsBaseTest`, `JWTSettingsDevTest` | параметры `SIMPLE_JWT` в базовых/dev-настройках |
| `PasswordValidatorsAbsentTest` | в проекте намеренно отключены стандартные валидаторы пароля |
| `CustomAdminLogoutTest` | кастомный logout из Django Admin |
| `ApplyGuestDataToUserTest` | заполнение полей User данными гостя, пришедшими из Remarked |
| `RemarkedGuestServiceSyncOnLoginTest` | подтягивание гостя из Remarked при логине |
| `VerifySMSRemarkedSyncIntegrationTest` | синхронизация с Remarked внутри `verify-sms` end-to-end |
| `MaybePushGuestToRemarkedTest` | условие, при котором профиль пушится в Remarked |
| `UserProfilePatchTriggersRemarkedPushTest` | `PATCH /profile/` инициирует пуш в Remarked |
| `PushGuestToRemarkedTaskTest` | Celery-задача пуша гостя в Remarked |
| `SyncGuestFromRemarkedTaskTest` | Celery-задача обратной синхронизации из Remarked |
| `UserGenderFieldTest` | поле `gender` модели `User` |

### bookings — 237 тестов (`apps/bookings/tests.py`)

Один (большой) файл. Помимо старой брони/сериализаторов/пушей, здесь теперь основная масса тестов — интеграция с Remarked (создание и синхронизация статусов брони) и Telegram-бот (уведомления, инлайн-кнопки, вебхук и его FSM). Классов `TableBookingStaffSerializerTest`, `StaffBookingListViewTest`, `StaffBookingUpdateViewTest` из старой версии документа в коде больше нет — отдельного Staff API для броней не существует, брони администрируются только через Django Admin.

| Класс | Что проверяет |
|---|---|
| `TableBookingSerializerTest` | guests_count (0 и 51 — невалидны, 50 — валидно), обязательные поля, read-only статус |
| `TableBookingSerializerWorkingHoursTest` | валидация времени брони относительно часов работы |
| `TableBookingListCreateViewTest` | пользователь видит только свои брони, создание брони, 401 без токена |
| `BookingSignalTest` | push при `confirmed`/`canceled`/`completed`, нет push при создании, нет push без пользователя, нет push если статус не изменился |
| `SendBookingRemindersTaskTest` | нет броней в окне → 0, push для `confirmed` брони в окне, пропуск `pending` и без пользователя, другая дата → пропуск |
| `TableBookingPhoneFieldTest`, `TableBookingPhoneAPITest` | поле телефона брони — валидация и API |
| `TableBookingZoneTest`, `TableBookingZoneAPITest` | `zone` — свободный текст (реальные названия залов из Remarked) |
| `BookingIdempotencyTest` | повторная отправка запроса на создание брони не плодит дубликаты |
| `BookingReminderRetryConfigTest`, `BookingReminderDeduplicationTest` | ретраи и дедупликация задачи напоминаний |
| `TelegramNotificationTaskTest`, `BookingSignalTelegramTest` | Celery-задача и сигнал отправки уведомления о брони в Telegram |
| `BuildBookingHtmlHelperTest`, `TgPostHelperTest` | хелперы формирования HTML-сообщения и запроса к Telegram Bot API |
| `TelegramNotificationInlineKeyboardTest` | инлайн-кнопки подтверждения/отмены под сообщением в Telegram |
| `TelegramWebhookSecretTest`, `TelegramWebhookBasicTest`, `TelegramWebhookConfirmTest`, `TelegramWebhookCancelTest`, `TelegramWebhookAlreadyProcessedTest`, `TelegramWebhookFSMTest` | вебхук Telegram-бота: проверка секрета, базовые сценарии, подтверждение/отмена брони, повторная обработка, переходы состояний FSM |
| `CreateReserveInRemarkedTaskTest`, `CreateReserveDispatchTest`, `CreateReserveInRemarkedFullStackTest` | создание брони в Remarked (Celery-задача, диспетчеризация, сквозной сценарий) |
| `SyncReserveStatusesTaskTest`, `SyncReserveStatusesBeatScheduleTest`, `SyncReserveStatusesFullStackTest` | периодическая синхронизация статусов брони из Remarked |
| `RemarkedRoomsServiceTest` | получение списка залов/столов из Remarked |
| `BookingZonesViewTest`, `BookingTablesViewTest` | `GET /api/v1/bookings/zones/` и `/tables/` |
| `CheckAvailabilityServiceTest`, `BookingAvailabilityViewTest`, `BookingAvailabilityFullStackTest` | проверка доступности слотов (сервис, API, сквозной сценарий) |

### events — 95 тестов (пакет `apps/events/tests/`)

Раньше был один файл `tests.py`, сейчас — пакет с пятью файлами:

| Файл | Классы | Что проверяет |
|---|---|---|
| `test_events.py` (63 теста) | `UpcomingEventsListViewTest`, `ArchivedEventsListViewTest`, `NewsListViewTest`, `EventReservationCreateViewTest`, `UserEventReservationsListViewTest`, `EventReservationSerializerTest`, `EventReservationSignalTest`, `EventReservationStaffSerializerTest`, `EventReservationIdempotencyTest`, `EventsCacheTest`, `EventPhotoReportModelTest`, `EventPhotoReportListViewTest`, `EventSerializerHasPhotoReportTest`, `NewsCacheTest`, `EventReservationAdminTest`, `EventFileCleanupTest`, `EventCapacityModelAndSerializerTest`, `EventCapacityAPITest` | публичные списки событий/новостей, запись на событие, кэширование, фотоотчёты, лимит вместимости события |
| `test_staff_event_serializer.py` (7 тестов) | `StaffEventSerializerTest` | сериализатор мероприятий для staff-эндпоинтов |
| `test_staff_event_views.py` (10 тестов) | `StaffEventViewSetTest` | CRUD-эндпоинты мероприятий для content_manager/admin |
| `test_staff_news_serializer.py` (6 тестов) | `StaffNewsSerializerTest` | сериализатор новостей для staff-эндпоинтов |
| `test_staff_news_views.py` (9 тестов) | `StaffNewsViewSetTest` | CRUD-эндпоинты новостей для content_manager/admin |

### menu — 85 тестов (пакет `apps/menu/tests/`)

Раньше был один файл `tests.py`, сейчас — пакет с четырьмя файлами:

| Файл | Классы | Что проверяет |
|---|---|---|
| `test_public_views.py` (58 тестов) | `CategoryListViewTest`, `TagListViewTest`, `DishListViewTest`, `CategoryModelTest`, `DishModelTest`, `CategoryCacheTest`, `DishCacheTest`, `MenuRedisResilienceTest`, `VideoFeedViewTest`, `DishSerializerVideoFieldsTest`, `TriggerVideoProcessingSignalTest`, `ProcessDishVideoTaskTest`, `DishFileCleanupTest` | публичные списки категорий/тегов/блюд, кэширование, видео-лента блюд и фоновая обработка видео |
| `test_allergen_views.py` (3 теста) | `AllergenListViewTest` | публичный список аллергенов |
| `test_staff_serializer.py` (11 тестов) | `StaffDishSerializerTest` | сериализатор блюд для staff-эндпоинтов |
| `test_staff_views.py` (13 тестов) | `StaffDishViewSetTest` | CRUD-эндпоинты блюд для content_manager/admin |

### core — 98 тестов (`apps/core/tests.py` + `test_logging_middleware.py` + `test_exception_handler.py`)

| Класс | Что проверяет |
|---|---|
| `RestaurantInfoModelTest` | `load()` создаёт запись, `save()` принудительно `pk=1`, `delete()` ничего не делает, вторая запись невозможна |
| `RestaurantInfoViewTest` | `GET /api/v1/core/info/` — публичный доступ, обязательные поля в ответе, nullable поля |
| `RestaurantInfoIsOpenNowTest` | расчёт «сейчас открыто/закрыто» по `working_hours` |
| `RestaurantInfoHeroFieldsTest` | поля hero-слайдов в ответе |
| `AppVersionViewTest` | `GET /api/v1/core/app-version/` |
| `RestaurantInfoMapLinksTest` | ссылки на 2ГИС/маршрут |
| `InteriorPhotoListViewTest` | публичный список фото интерьера |
| `DishMultiTagFilterTest` | фильтрация блюд по нескольким тегам (кросс-модульный тест из core) |
| `WorkingHoursNoteTest` | временное уведомление о часах работы |
| `RestaurantInfoAdminAccessTest`, `AppVersionAdminAccessTest` | доступ к этим разделам в Django Admin по ролям |
| `SeedInitialDataCommandTest`, `SeedInitialDataIdempotentTest`, `SeedInitialDataForceTest` | management-команда наполнения начальными данными |
| `HealthCheckOkTest`, `HealthCheckRedisDownTest` | `/health/` при живом и упавшем Redis |
| `RestaurantInfoCacheTest`, `InteriorPhotoCacheTest`, `CoreRedisResilienceTest` | кэширование и устойчивость к недоступности Redis |
| `CoreFileCleanupTest` | удаление файлов при удалении/замене записей |
| `JsonFormatterTests`, `RequestLoggingMiddlewareTests` (`test_logging_middleware.py`) | форматирование логов в JSON, middleware логирования запросов |
| `CustomExceptionHandlerTest` (`test_exception_handler.py`) | кастомный DRF exception handler |

### notifications — 60 тестов (`apps/notifications/tests.py`)

| Класс | Что проверяет |
|---|---|
| `RegisterDeviceViewTest` | регистрация нового → 201, перепривязка существующего токена → 200, 401 без токена, один пользователь — несколько устройств |
| `UserDeviceModelTest` | `__str__`, уникальность `fcm_token` |
| `SendPushNotificationTaskTest` | нет устройств → Firebase не вызывается, отправка на все устройства, удаление невалидных токенов, передача `data`, `data={}` по умолчанию |
| `SendPushNotificationCategoryTest` | пропуск при выключенных `notify_events`/`notify_promotions`/`notify_closed_events`, отправка при `category=None` и неизвестной категории, несуществующий пользователь → пропуск |
| `SendBulkPushNotificationTaskTest` | одна задача на пользователя, пустой список → 0, передача `category` и `data` в подзадачи |
| `BulkPushViewTest` | обычный пользователь → 403, 401 без токена, отсутствие `title` → 400, `segment=all` → 202, корректный подсчёт уникальных пользователей, `participated_in_event` без `event_id` → 400, `registered_after` без даты → 400, `last_visit_days` → 202 |
| `PushWeeklyLimitTest` | еженедельный лимит некритичных пушей на пользователя |
| `PushTimeWindowTest` | отправка некритичных пушей только в окне 9:00–21:00 |
| `PushCampaignTest` | модель/логика рассылки `PushCampaign` |
| `NotificationsEnabledFlagTest` | общий флаг включения уведомлений у пользователя |
| `CeleryRetryConfigTest` | конфигурация ретраев push-задач |
| `FirebaseStartupValidationTest` | проверка инициализации Firebase при старте |
| `SendPushViaBotViewTest` | отправка сервисного пуша через Telegram-бота |

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
| Throttling (3/min, 5/min) | Проверяется вручную или в интеграционных тестах с Redis (кроме троттлинга SMS по телефону — он покрыт `PhoneSMSThrottleTest`) |
| Django-админка (UI/вёрстка) | Стандартный Django — тесты не нужны. Логика прав доступа (`has_*_permission` по ролям) частично покрыта — см. `RestaurantInfoAdminAccessTest`, `AppVersionAdminAccessTest`, `EventReservationAdminTest` |
| Миграции | Проверяются при `manage.py migrate` |
| S3-хранилище | Требует реального MinIO/S3 — выходит за рамки unit-тестов |

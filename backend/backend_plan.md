# План коррекции Backend — Piligrim App

## Context
По результатам аудита backend-а относительно ТЗ (TZ Piligrim App.pdf) выявлено 11 расхождений.
Часть из них критична для MVP (пользователь или ресторан заметит сразу), часть — UX-дополнения.
Каждый тикет содержит: затрагиваемые файлы, что делать, и обновление документации в `backend/docs/`.

---

## TICKET-01 · Push при создании заявки на бронирование

**ТЗ:** «Гость получает push: "Заявка принята, мы свяжемся с вами в течение N минут"»

**Проблема:** Сигнал `notify_on_status_change` в `bookings/signals.py` делает `return` при `created=True`, push не отправляется.

**Файлы:**
- `backend/apps/bookings/signals.py` — добавить ветку `if created`
- `backend/apps/notifications/tasks.py` — уже содержит `send_push_notification`, переиспользуем

**Что делать:**
1. В `notify_on_status_change`: убрать ранний `return` при `created=True`, вместо этого отправить push с текстом "Заявка принята, мы свяжемся с вами" при `created=True and instance.user_id`
2. Добавить текст в `_STATUS_PUSH` или отдельным блоком для `created`

**Документация:** Обновить `backend/docs/bookings.md` — раздел "Push-уведомления": добавить описание события создания заявки.

---

## TICKET-02 · Напоминание о визите за 1–2 часа (Celery Beat)

**ТЗ:** «За некоторое время до визита (1–2 часа) — напоминание push-ом»

**Проблема:** Нет Celery Beat, нет периодической задачи проверки предстоящих броней.

**Файлы:**
- `backend/apps/bookings/tasks.py` — создать
- `backend/config/celery.py` — добавить `beat_schedule`
- `backend/config/settings/base.py` — добавить `CELERY_BEAT_SCHEDULE`

**Что делать:**
1. Создать `bookings/tasks.py` с задачей `send_booking_reminders`:
   - Выбирает `TableBooking` со статусом `confirmed`
   - Где `date` = сегодня, `time` входит в окно [now + 1h, now + 2h]
   - Вызывает `send_push_notification.delay(user_id, title, body, data)`
2. В `celery.py` / `settings/base.py` добавить `beat_schedule` с запуском каждые 15 минут
3. Добавить зависимость `django-celery-beat` или использовать native celery beat

**Документация:** Создать/обновить `backend/docs/bookings.md` — раздел "Напоминания"; обновить `backend/docs/notifications.md` — перечень событий push.

---

## TICKET-03 · Поля Dish: weight + story

**ТЗ:** «Свайп вправо — расширенное описание, состав, аллергены, **вес**, **история блюда**»

**Проблема:** В модели `Dish` нет полей `weight` и `story`.

**Файлы:**
- `backend/apps/menu/models.py` — добавить поля
- `backend/apps/menu/serializers.py` — добавить поля в `DishSerializer`
- `backend/apps/menu/migrations/` — создать новую миграцию

**Что делать:**
1. Добавить в `Dish`:
   - `weight = models.PositiveIntegerField("Вес (г)", null=True, blank=True)`
   - `story = models.TextField("История блюда", blank=True)`
2. Добавить `'weight', 'story'` в `DishSerializer.Meta.fields`
3. Создать миграцию `0002_dish_weight_story.py`

**Документация:** Обновить `backend/docs/menu.md` — таблица полей модели `Dish`, описание сериализатора.

---

## TICKET-04 · Поля Event: format + price

**ТЗ:** «Карточка мероприятия: **формат** (открытое / закрытое), **цена входа** (если применимо)»

**Проблема:** В модели `Event` нет полей `format` и `price`.

**Файлы:**
- `backend/apps/events/models.py` — добавить поля
- `backend/apps/events/serializers.py` — добавить в `EventSerializer`
- `backend/apps/events/migrations/` — создать миграцию `0003_event_format_price.py`

**Что делать:**
1. Добавить в `Event`:
   - `format = models.CharField("Формат", max_length=10, choices=[('open','Открытое'),('closed','Закрытое')], default='open')`
   - `price = models.DecimalField("Цена входа", max_digits=10, decimal_places=2, null=True, blank=True)`
2. Добавить `'format', 'price'` в `EventSerializer.Meta.fields`

**Документация:** Обновить `backend/docs/events.md` — таблица полей `Event`, примеры ответа API.

---

## TICKET-05 · Поле TableBooking: zone/hall (опционально)

**ТЗ:** «Зона / зал — опционально (главный зал, терраса, приват)»

**Проблема:** В `TableBooking` нет поля зоны.

**Файлы:**
- `backend/apps/bookings/models.py` — добавить поле
- `backend/apps/bookings/serializers.py` — добавить в `TableBookingSerializer`
- `backend/apps/bookings/migrations/` — создать миграцию `0003_tablebooking_zone.py`

**Что делать:**
1. Добавить в `TableBooking`:
   - `zone = models.CharField("Зона/зал", max_length=50, blank=True, null=True)`
2. Добавить `'zone'` в `TableBookingSerializer.Meta.fields`

**Документация:** Обновить `backend/docs/bookings.md` — таблица полей, пример запроса.

---

## TICKET-06 · Per-category push preferences

**ТЗ:** «Пользователь включает/выключает каждую категорию: мероприятия, закрытые события, акции, сервисные (не отключаются)»

**Проблема:** В `User` один булевый флаг `notifications_enabled` — нет разбивки по категориям.

**Файлы:**
- `backend/apps/users/models.py` — заменить/расширить поля уведомлений
- `backend/apps/users/serializers.py` — добавить поля в `UserProfileSerializer`
- `backend/apps/users/migrations/` — создать миграцию `0003_user_notification_prefs.py`
- `backend/apps/notifications/tasks.py` — учитывать категорию при отправке

**Что делать:**
1. Убрать `notifications_enabled` (или оставить как мастер-флаг), добавить:
   - `notify_events = models.BooleanField("Уведомления: мероприятия", default=True)`
   - `notify_promotions = models.BooleanField("Уведомления: акции", default=True)`
   - `notify_closed_events = models.BooleanField("Уведомления: закрытые события", default=True)`
   - Сервисные (бронь) — без флага, всегда включены
2. Добавить поля в `UserProfileSerializer`
3. В `send_push_notification(user_id, title, body, data, category=None)` — добавить параметр `category` и проверять соответствующий флаг пользователя перед отправкой

**Документация:** Обновить `backend/docs/users.md` — поля профиля; `backend/docs/notifications.md` — категории и управление настройками.

---

## TICKET-07 · Поиск по меню

**ТЗ:** «Классическое меню — поиск по меню»

**Проблема:** `DishFilter` фильтрует только по `category_id` и `tag_id`. Search отсутствует.

**Файлы:**
- `backend/apps/menu/filters.py` — добавить поиск
- `backend/apps/menu/views.py` — добавить `SearchFilter` в `filter_backends`

**Что делать:**
1. В `DishFilter` добавить:
   - `name = django_filters.CharFilter(lookup_expr='icontains')`
2. Либо в `DishListView` добавить `SearchFilter` из DRF:
   - `filter_backends = [DjangoFilterBackend, SearchFilter]`
   - `search_fields = ['name', 'description']`
   - Query param: `?search=...`
3. Обновить OpenAPI-аннотацию в `views.py` — добавить параметр `search`

**Документация:** Обновить `backend/docs/menu.md` — раздел фильтрации, пример запроса с `search`.

---

## TICKET-08 · RestaurantInfo: контакты, is_open_now, правила, юридика

**ТЗ:** «Адрес, телефон, мессенджеры (WhatsApp, Telegram, Instagram), маршрут; статус открыто/закрыто; правила посещения; соглашение и политика ПД»

**Проблема:** `RestaurantInfo` содержит только `address`, `working_hours`, `tour_link`, `twogis_link`.

**Файлы:**
- `backend/apps/core/models.py` — добавить поля
- `backend/apps/core/serializers.py` — расширить
- `backend/apps/core/migrations/` — создать `0002_restaurantinfo_contacts_legal.py`

**Что делать:**
1. Добавить поля в `RestaurantInfo`:
   - `phone = models.CharField("Телефон", max_length=20, blank=True)`
   - `whatsapp = models.CharField("WhatsApp", max_length=100, blank=True)`
   - `telegram = models.CharField("Telegram", max_length=100, blank=True)`
   - `instagram = models.CharField("Instagram", max_length=100, blank=True)`
   - `visit_rules = models.TextField("Правила посещения", blank=True)`
   - `privacy_policy = models.TextField("Политика обработки ПД", blank=True)`
   - `terms_of_service = models.TextField("Пользовательское соглашение", blank=True)`
2. Добавить `property is_open_now` — парсит `working_hours` по часовому поясу `Asia/Almaty` и возвращает bool
3. Добавить все поля + `is_open_now` в `RestaurantInfoSerializer`

**Документация:** Обновить `backend/docs/core.md` — полная таблица полей, описание `is_open_now`.

---

## TICKET-09 · Роли в Django Admin

**ТЗ:** «Администратор (полный), Менеджер зала (только брони/мероприятия), Контент-менеджер (меню/афиша/push)»

**Проблема:** Используется стандартный `is_staff/is_superuser`. Кастомных ролей нет.

**Файлы:**
- `backend/apps/users/models.py` — добавить поле `role`
- `backend/apps/users/admin.py` — настроить `ModelAdmin` с `get_queryset` / `has_*_permission` по роли
- `backend/apps/bookings/admin.py`, `backend/apps/events/admin.py`, `backend/apps/menu/admin.py`, `backend/apps/notifications/admin.py` — ограничить доступ по роли
- `backend/apps/users/migrations/` — миграция

**Что делать:**
1. Добавить в `User`:
   - `role = models.CharField("Роль", max_length=20, choices=[('admin','Администратор'),('hall_manager','Менеджер зала'),('content_manager','Контент-менеджер')], blank=True)`
2. В каждом `ModelAdmin` переопределить `has_add_permission`, `has_change_permission`, `has_delete_permission` с проверкой `request.user.role`
   - Менеджер зала: только `TableBooking`, `EventReservation`
   - Контент-менеджер: `Dish`, `Category`, `Tag`, `Allergen`, `Event`, `News`; push-задачи
   - Администратор: полный доступ

**Документация:** Создать `backend/docs/admin.md` — описание ролей, таблица разрешений.

---

## TICKET-10 · Массовая отправка push + сегментация аудитории

**ТЗ:** «В админ-панели: отправка по всем пользователям или по сегментам (дата последнего визита, участие в мероприятиях, дата регистрации)»

**Проблема:** `send_push_notification` работает только для одного `user_id`. Нет endpoint-а и инструмента массовой отправки.

**Файлы:**
- `backend/apps/notifications/tasks.py` — добавить `send_bulk_push_notification`
- `backend/apps/notifications/views.py` — добавить `BulkPushView` (только для `is_staff`)
- `backend/apps/notifications/serializers.py` — добавить `BulkPushSerializer`
- `backend/apps/notifications/urls.py` — добавить маршрут

**Что делать:**
1. Celery-задача `send_bulk_push_notification(user_ids, title, body, data, category)` — итерирует по `user_ids`, вызывает `send_push_notification.delay`
2. `BulkPushSerializer` с полями: `title`, `body`, `data`, `category`, `segment` (all / last_visit_days / participated_in_event / registered_after)
3. `BulkPushView.post` — принимает сегмент, составляет `user_ids` через ORM-запрос, запускает задачу
4. Маршрут: `POST /api/notifications/bulk-push/`

**Документация:** Обновить `backend/docs/notifications.md` — раздел "Массовая рассылка", описание сегментов и параметров.

---

## TICKET-11 · SMS-провайдер (боевой режим)

**ТЗ:** Авторизация через реальный SMS. В production заглушка возвращает `True` без отправки.

**Проблема:** В `users/services.py` продакшн-блок закомментирован; `return True` при `DEBUG=False`.

**Файлы:**
- `backend/apps/users/services.py` — раскомментировать и реализовать HTTP-запрос к провайдеру
- `backend/.env.example` — добавить переменные `SMS_PROVIDER_URL`, `SMS_LOGIN`, `SMS_PASSWORD`
- `backend/config/settings/base.py` — добавить `SMS_*` переменные через `env()`

**Что делать:**
1. В `SMSService.send_sms`:
   - Читать `settings.SMS_PROVIDER_URL`, `SMS_LOGIN`, `SMS_PASSWORD`
   - Заменить заглушку на `requests.post(...)` с обработкой ошибок и логированием
   - `return response.status_code == 200`
2. Добавить `requests` в зависимости (уже в venv, но убедиться в `requirements.txt`)
3. Добавить переменные в `.env.example`

**Документация:** Обновить `backend/docs/users.md` — раздел "SMS-сервис", описание переменных окружения.

---

## Приоритеты

| # | Тикет | Приоритет | Причина |
|---|---|---|---|
| 01 | Push при создании брони | 🔴 Критично | Пользователь не получает подтверждение |
| 02 | Напоминание за 1–2 ч | 🔴 Критично | Явное требование ТЗ |
| 06 | Per-category push prefs | 🔴 Критично | ТЗ: обязательное управление уведомлениями |
| 03 | Dish: weight + story | 🟠 Важно | Нужно для полной карточки блюда |
| 04 | Event: format + price | 🟠 Важно | Нужно для отображения карточки мероприятия |
| 08 | RestaurantInfo extended | 🟠 Важно | Контакты — основной UI раздела профиля |
| 07 | Поиск по меню | 🟡 Средне | Классический режим меню без поиска неполный |
| 05 | Booking: zone field | 🟡 Средне | Опционально по ТЗ |
| 11 | SMS-провайдер | 🟡 Средне | Критично для production, но может ждать интеграцию |
| 09 | Роли в Admin | 🟡 Средне | Нужно до передачи контент-менеджеру |
| 10 | Bulk push + сегментация | 🔵 Позже | После базового push-flow |

---

## Верификация (после реализации каждого тикета)

- **Тикеты 01, 02, 06, 10:** запустить Celery worker + beat, создать/изменить бронирование — проверить FCM-доставку в Firebase Console
- **Тикеты 03, 04, 05, 08:** запустить `python manage.py migrate`, проверить Swagger (`/api/docs/`) — новые поля отображаются
- **Тикет 07:** `GET /api/menu/dishes/?search=бургер` — возвращает отфильтрованный результат
- **Тикет 09:** зайти в Django Admin под пользователем с `role=hall_manager` — нет доступа к меню/push
- **Тикет 11:** поставить `DEBUG=False` + реальные SMS-credentials, запросить OTP — SMS приходит на телефон
- **Документация:** после каждого тикета убедиться, что соответствующий `docs/*.md` обновлён и отражает актуальный API/модель

# План удаления Telegram-логики

> **Зачем:** брони и рассылка пушей переезжают в remarked-CRM. Telegram-бот
> (уведомления менеджерам + FSM-рассылка пушей) становится полностью избыточным.
> Этот файл — чек-лист на будущее: **что, где, в каком порядке** удалять и **как проверить**.
>
> **Статус:** НЕ УДАЛЕНО. Всё закрыто env-переменными (`TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID`),
> без них код спит. Удаление — плановая чистка, не блокер.

---

## ⚠️ НЕ ТРОГАТЬ (ложные срабатывания по слову "telegram")

Это **контакт ресторана**, а не бот. Оставить как есть:

- `apps/core/models.py` — поле `RestaurantInfo.telegram` (`@panno_almaty`)
- `apps/core/serializers.py`, `apps/core/admin.py` — то же поле
- `backend/docs/core.md`, `API_FOR_FLUTTER.md` (строки ~365, ~403) — описание контакта
- Старые миграции `apps/users/migrations/0007_user_telegram_id.py` и др. — **история, не удаляем**.
  Поле убирается новой миграцией (см. шаг 6), а не правкой старых файлов.

---

## Что делает Telegram (обе функции уходят)

1. **Уведомления о бронях менеджерам** + кнопки «Подтвердить/Отменить» из чата.
2. **FSM-рассылка пушей** через бота (менеджер создаёт push по шагам) + endpoint `send-push-via-bot/`.

**Оставляем нетронутым:** всю FCM-инфраструктуру — `UserDevice`, `send_push_notification`,
`send_bulk_push_notification`, `PushCampaign`, `POST /bulk-push/`, `send_booking_reminders`.
Это система доставки пушей; Telegram был лишь одним из триггеров.

---

## Порядок удаления

Идём «от вызывающих к вызываемым», чтобы не ловить `ImportError` на промежуточных шагах.

### Шаг 1 — Сигналы (убрать вызовы задач)

- **`apps/bookings/signals.py`**
  - Удалить строки `from apps.bookings.tasks import send_telegram_notification`
    и `_safe_delay(send_telegram_notification, instance.pk)` (~строки 47-48).
  - Поправить лог-строку 49: `"Push+Telegram queued"` → `"Push queued"`.
  - **Оставить** всю push-логику.

- **`apps/events/signals.py`**
  - Удалить блок «Отправка уведомления менеджеру в Telegram» (~строки 59-67:
    импорт `send_event_reservation_telegram_notification` + `try/except .delay`).
  - **Оставить** блок push-уведомления пользователю.

### Шаг 2 — URLs (убрать роуты)

- **`apps/bookings/urls.py`** — удалить строку с `telegram-webhook/`; в импорте убрать `TelegramWebhookView`.
- **`apps/notifications/urls.py`** — удалить строку с `send-push-via-bot/`; в импорте убрать `SendPushViaBotView`.

### Шаг 3 — Views

- **`apps/bookings/views.py`**
  - Удалить целиком класс `TelegramWebhookView` и функцию `_get_manager_keyboard`.
  - Удалить импорт `from .tasks import _build_booking_html, _tg_post`.
  - Подчистить ставшие ненужными импорты: `html`, `json`, `requests`, `cache`, `settings`,
    `JsonResponse`, `method_decorator`, `View`, `csrf_exempt`.
    (Оставить то, что нужно `TableBookingListCreateView`: `generics`, `IsAuthenticated`,
    `extend_schema*`, `IdempotencyMixin`, `StandardPagination`, модель, сериализатор, `logging`.)

- **`apps/notifications/views.py`**
  - Удалить целиком класс `SendPushViaBotView` (~строки 198-265).
  - В импорте (строка 10) убрать `SendPushViaBotSerializer`.

### Шаг 4 — Serializers

- **`apps/notifications/serializers.py`** — удалить класс `SendPushViaBotSerializer` (~строки 32-42).

### Шаг 5 — Tasks

- **`apps/bookings/tasks.py`**
  - Удалить задачи `send_telegram_notification` и `send_event_reservation_telegram_notification`.
  - Удалить хелперы `_build_booking_html`, `_tg_post`, константу `_ZONE_LABELS`.
  - Удалить импорты `html`, `requests` (их использовал только Telegram).
  - **Оставить** `send_booking_reminders` — это push-напоминания, не Telegram.

### Шаг 6 — Поле модели `telegram_id`

- **`apps/users/models.py`** — удалить поле `telegram_id` (~строки 50-57).
- **`apps/users/admin.py`** — убрать `telegram_id` из `list_display` (43), `search_fields` (45),
  `fieldsets` (50).
- Сгенерировать миграцию:
  ```bash
  cd backend
  python manage.py makemigrations users   # создаст миграцию удаления telegram_id
  ```

### Шаг 7 — Настройки и env

- **`config/settings/base.py`** — удалить `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`,
  `TELEGRAM_WEBHOOK_SECRET` (~строки 218-221).
- **`config/settings/prod.py`** — удалить 3 записи `TELEGRAM_*` из словаря валидации (~строки 35-37).
- **`config/settings/test.py`** — удалить оверрайды `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` (~строки 38-40).
- **`backend/.env.example`** — удалить блок «Telegram-бот» (~строки 100-103).

### Шаг 8 — Тесты

- **`apps/bookings/tests.py`** — удалить классы:
  `TelegramNotificationTaskTest`, `BookingSignalTelegramTest`, `BuildBookingHtmlHelperTest`,
  `TgPostHelperTest`, `TelegramNotificationInlineKeyboardTest`, `TelegramWebhookSecretTest`,
  `TelegramWebhookBasicTest`, `TelegramWebhookConfirmTest`, `TelegramWebhookCancelTest`,
  `TelegramWebhookAlreadyProcessedTest`, `TelegramWebhookFSMTest`.
- **`apps/notifications/tests.py`** — удалить класс `SendPushViaBotViewTest`.
- **Важно:** после удаления поля `telegram_id` найти и убрать все `telegram_id='...'`
  в вызовах `create_user(...)` в оставшихся тестах — иначе `TypeError`:
  ```bash
  grep -rn "telegram_id" backend/apps/*/tests.py
  ```

### Шаг 9 — Документация

- **`backend/docs/bookings.md`** — удалить разделы «Telegram-уведомления для менеджеров».
- **`backend/docs/notifications.md`** — удалить упоминания бота / `send-push-via-bot`.
- **`backend/docs/events.md`** — убрать упоминание telegram-уведомления менеджеру.
- **`backend/README.md`** — удалить строку с роутом `telegram-webhook/` (~62), описание бота (~68),
  env-переменные `TELEGRAM_*` (~132-134).
- Этот файл (`telegram_removal.md`) удалить в самом конце, когда всё сделано.

---

## Как проверить, что ничего не осталось

```bash
cd backend

# 1. По коду не должно остаться ни одного упоминания бота/поля.
#    Допустимы ТОЛЬКО совпадения по контакту RestaurantInfo.telegram в core.
grep -rin "telegram" apps/ config/ | grep -viE "core/|restaurantinfo|contact"
grep -rin "telegram_id\|send_telegram\|TelegramWebhook\|SendPushViaBot\|send-push-via-bot\|TELEGRAM_BOT\|TELEGRAM_CHAT\|TELEGRAM_WEBHOOK" apps/ config/
#   → обе команды должны вернуть пусто

# 2. Django видит консистентную конфигурацию
python manage.py check

# 3. Миграция удаления поля создана и применяется
python manage.py makemigrations users --check   # не должно быть НЕсозданных изменений
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py migrate

# 4. Полный прогон тестов — всё зелёное
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps

# 5. OpenAPI-схема без telegram-эндпоинтов
python manage.py spectacular --file openapi.yaml
grep -i "telegram\|via-bot" openapi.yaml   # → пусто
```

**Критерий готовности:** команды grep пустые (кроме контакта в core), `check` без ошибок,
все тесты проходят, в OpenAPI нет `telegram-webhook` и `send-push-via-bot`.

---

## Сводка затронутых файлов

| Файл | Действие |
|---|---|
| `apps/bookings/signals.py` | убрать вызов telegram-задачи |
| `apps/events/signals.py` | убрать блок telegram-уведомления |
| `apps/bookings/urls.py` | убрать роут `telegram-webhook/` |
| `apps/notifications/urls.py` | убрать роут `send-push-via-bot/` |
| `apps/bookings/views.py` | удалить `TelegramWebhookView` + `_get_manager_keyboard` |
| `apps/notifications/views.py` | удалить `SendPushViaBotView` |
| `apps/notifications/serializers.py` | удалить `SendPushViaBotSerializer` |
| `apps/bookings/tasks.py` | удалить 2 telegram-задачи + хелперы (оставить `send_booking_reminders`) |
| `apps/users/models.py` | удалить поле `telegram_id` → **новая миграция** |
| `apps/users/admin.py` | убрать `telegram_id` из admin |
| `config/settings/base.py` `prod.py` `test.py` | убрать `TELEGRAM_*` |
| `backend/.env.example` | убрать блок Telegram |
| `apps/bookings/tests.py`, `apps/notifications/tests.py` | удалить telegram-тесты + `telegram_id=` в create_user |
| `docs/bookings.md`, `docs/notifications.md`, `docs/events.md`, `README.md` | убрать разделы про бота |

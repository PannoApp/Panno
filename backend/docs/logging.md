# Система логирования (Logging)

В проекте Piligrim Backend реализована production-ready система логирования всех HTTP-запросов. Она построена на базе встроенной библиотеки Python `logging` и кастомного Middleware, что позволяет собирать статистику запросов, отлаживать ошибки и маскировать чувствительные данные без использования сторонних зависимостей.

---

## 1. Архитектура логирования

Система состоит из трёх компонентов:

1. **`RequestLoggingMiddleware`** (`utils/logging_middleware.py`) — перехватывает запросы/ответы и пишет JSON-лог.
2. **`JsonFormatter`** (`utils/logging_middleware.py`) — форматирует записи лога как JSON.
3. **`custom_exception_handler`** (`utils/exception_handler.py`) — кастомный обработчик исключений DRF (см. ниже).

---

## 1a. Кастомный обработчик исключений DRF (`utils/exception_handler.py`)

Зарегистрирован в `REST_FRAMEWORK['EXCEPTION_HANDLER']` в `config/settings/base.py`.

**Проблема без него:** если внутри DRF-view возникает обычное Python-исключение (`KeyError`, `AttributeError` и т.п.), стандартный DRF-хендлер возвращает `None`. Django тогда отдаёт HTML-страницу (`DEBUG=True`) или пустое тело без JSON (`DEBUG=False`). Flutter падает при попытке распарсить такой ответ.

**Поведение с ним:**

| Тип исключения | Что происходит | HTTP-статус |
|---|---|---|
| Наследник `APIException` (ValidationError, PermissionDenied и т.д.) | DRF обрабатывает штатно | 400 / 401 / 403 / … |
| Любое другое Python-исключение | Хендлер перехватывает, логирует `ERROR` + traceback, возвращает JSON | 500 |

**Формат JSON-ответа при 500:**
```json
{"detail": "Внутренняя ошибка сервера."}
```

**Лог при необработанном исключении:**
```
ERROR | Необработанное исключение в MyView | traceback: ...
```

---

## 2. Формат логов и Уровни (RequestLoggingMiddleware)

Все логи пишутся в формате JSON. Система делит логи на два уровня в зависимости от исхода запроса:

1. **`RequestLoggingMiddleware`** — перехватывает входящие запросы и исходящие ответы. Замеряет время выполнения и собирает метаданные (метод, путь, ID пользователя, статус ответа).
2. **`JsonFormatter`** — преобразует собранные данные в структурированные JSON-строки, что идеально подходит для сбора логов через ELK Stack (Elasticsearch, Logstash, Kibana), Datadog, Grafana Loki или другие системы мониторинга.

---

## 2. Формат логов и Уровни

Все логи пишутся в формате JSON. Система делит логи на два уровня в зависимости от исхода запроса:

### `INFO` (Успешные запросы и ошибки клиента)
Для любых HTTP-статусов `< 500` (например, `200 OK`, `400 Bad Request`, `401 Unauthorized` и т.д.) пишется короткая сводка. 
Тело запроса и заголовки **не логируются** для экономии места.

**Пример (отформатировано для удобства):**
```json
{
  "time": "2026-05-11 14:30:00",
  "level": "INFO",
  "message": "Request: POST /api/v1/users/auth/request-sms/ - 200",
  "method": "POST",
  "path": "/api/v1/users/auth/request-sms/",
  "status_code": 200,
  "user_id": "15",
  "duration": 0.0452
}
```

#### Поле `user_id` и JWT-аутентификация

`user_id` всегда логируется **после** завершения обработки запроса (`self.get_response(request)`). Это принципиально для корректной работы с JWT:

* `AuthenticationMiddleware` (позиция 6 в `MIDDLEWARE`) устанавливает `request.user` через сессии → для JWT-запросов это `AnonymousUser`.
* DRF выполняет `JWTAuthentication` внутри `APIView.dispatch()` и устанавливает `request.user = jwt_user` на уровне Django-запроса через `Request.user` setter (`self._request.user = value`).
* После `get_response` `request.user` уже содержит аутентифицированного пользователя → `get_user_id()` возвращает реальный `str(user.id)`.

Значения поля:
| Ситуация | `user_id` |
|---|---|
| Аутентифицированный JWT-запрос | `"15"` (числовой ID) |
| Неаутентифицированный запрос | `"Anonymous"` |
| Неверный / просроченный токен | `"Anonymous"` |

### `ERROR` (Серверные ошибки и исключения)
Для HTTP-статусов `>= 500` или при падении (когда срабатывает `process_exception`) пишется подробный лог. Дополнительно захватываются:
* `headers` (заголовки запроса)
* `query_params` (параметры строки запроса)
* `body` (тело запроса)
* `traceback` (полный стек вызовов, если произошло исключение)

**Пример ошибки:**
```json
{
  "time": "2026-05-11 14:35:12",
  "level": "ERROR",
  "message": "Unhandled Exception: POST /api/v1/menu/items/",
  "method": "POST",
  "path": "/api/v1/menu/items/",
  "status_code": 500,
  "user_id": "15",
  "duration": 0.1205,
  "headers": {"Content-Type": "application/json", "Authorization": "***"},
  "query_params": {},
  "body": "{\"name\": \"Steak\", \"price\": \"invalid\"}",
  "traceback": "Traceback (most recent call last):\n  File \"...\"\nValueError: invalid literal for int()"
}
```

---

## 3. Безопасность и Маскировка (Data Masking)

Для соответствия стандартам безопасности, некоторые данные маскируются «на лету» и заменяются на строку `***` **до** записи в файл.

### Заголовки (`_SENSITIVE_HEADERS`)

Следующие заголовки полностью скрываются в логах ERROR:

| Заголовок | Что содержит |
|---|---|
| `Authorization` | JWT Bearer-токен |
| `Cookie` | Сессионные cookie |
| `Set-Cookie` | Cookie, выставляемые сервером |
| `X-Api-Key` | API-ключ |
| `X-Api-Secret` | API-секрет |

### Поля тела запроса (`_SENSITIVE_BODY_FIELDS`)

Если тело запроса — валидный JSON, следующие поля заменяются на `***`:

| Поле | Что содержит |
|---|---|
| `otp` | SMS-код подтверждения |
| `password` | Пароль (admin-интерфейс) |
| `token` | Токен (любые форматы) |
| `secret` | Секрет / ключ |

*Важно:* Извлечение тела запроса обернуто в безопасный `try-except` блок для предотвращения ошибок `RawPostDataException`.

---

## 4. Конфигурация хранения (settings/base.py)

Файлы логов сохраняются локально в папку `logs/`, которая создается автоматически в корне проекта. 

Настроен **RotatingFileHandler**:
* **Путь:** `logs/app.log`
* **Максимальный размер:** 10 МБ (`maxBytes = 10 * 1024 * 1024`). Как только файл превышает этот размер, он архивируется (переименовывается в `app.log.1`, `app.log.2` и т.д.).
* **Хранение архивов:** Хранятся последние 5 файлов логов (`backupCount = 5`). Более старые автоматически удаляются, защищая сервер от переполнения диска.
* Логи также дублируются в стандартный вывод (консоль), чтобы их можно было смотреть через `docker-compose logs -f`.

---

## 5. Инфраструктура и Docker

В `docker-compose.yml` настроен "проброс" (bind mount) директории `logs`. Это гарантирует, что логи не исчезнут при остановке контейнера (`docker-compose down`) или пересборке образа.

```yaml
    volumes:
      # Пробрасываем папку логов на хост-машину
      - ./logs:/app/backend/logs 
```

Вы можете просматривать логи "вживую" на хост-машине с помощью обычных утилит:
```bash
tail -f logs/app.log
```
Или просматривать их в консоли Docker с форматированием JSON (например, через утилиту `jq`):
```bash
tail -f logs/app.log | jq
```

---

## 6. Тестирование

Логика маскировки и форматирования покрыта автоматическими тестами в `apps/core/test_logging_middleware.py`.
Тесты используют легковесный `SimpleTestCase`, не требующий подключения к БД.

Кастомный обработчик исключений покрыт тестами в `apps/core/test_exception_handler.py` (7 тестов):
- DRF-исключение обрабатывается штатно (400, JSON)
- Python-исключение → 500, `Content-Type: application/json`, тело `{"detail": "..."}`
- Исключение логируется как ERROR с именем view

Запуск тестов логирования:
```bash
docker compose exec backend python manage.py test apps.core.test_logging_middleware --settings=config.settings.test
docker compose exec backend python manage.py test apps.core.test_exception_handler --settings=config.settings.test
```

---

## 5. Устойчивость к падению Redis (`utils/cache.py`)

Все обращения к Redis-кэшу в Django-вью и сигналах обёрнуты в safe-хелперы из `utils/cache.py`.

### Хелперы

| Функция | Поведение при недоступном Redis |
|---|---|
| `safe_cache_get(key, default=None)` | Возвращает `default`, логирует `WARNING` |
| `safe_cache_set(key, value, timeout)` | Пропускает запись, логирует `WARNING` |
| `safe_cache_delete(key)` | Пропускает удаление, логирует `WARNING` |
| `safe_cache_get_or_set(key, fn, timeout)` | Вызывает `fn()` напрямую, логирует `WARNING` |
| `safe_cache_add(key, value, timeout)` | Возвращает `True`, логирует `WARNING` |

### Поведение при падении Redis

| Сценарий | Было | Стало |
|---|---|---|
| `GET /api/v1/menu/categories/` | 500 | 200 (запрос к БД) |
| `GET /api/v1/menu/dishes/` | 500 | 200 (запрос к БД) |
| `GET /api/v1/core/info/` | 500 | 200 (запрос к БД) |
| `GET /api/v1/core/interior/` | 500 | 200 (запрос к БД) |
| `POST /api/v1/users/auth/request-sms/` | 500 | 503 (Redis обязателен для OTP) |
| Создание бронирования (сигнал push) | 500 | 201 (уведомление теряется, бронь сохраняется) |
| Инвалидация кэша меню через сигнал | crash | тихий WARNING |

### Логи при падении Redis

```
WARNING Redis unavailable — cache.get(menu_categories) skipped
WARNING Redis unavailable — cache.set(menu_categories) skipped
ERROR   Redis unavailable — OTP for +77001234567 not stored, SMS aborted
ERROR   Celery broker unavailable — task send_push_notification not queued
```

### Запуск тестов resilience:
```bash
docker compose exec backend bash -c "DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test utils.tests apps.users.tests apps.bookings.tests apps.menu.tests apps.core.tests"
```

# Модуль: users

Отвечает за авторизацию пользователей через SMS OTP и управление профилем.

## Как устроена авторизация

Пароли не используются. `UserManager.create_user()` всегда вызывает `set_unusable_password()`, поэтому `AUTH_PASSWORD_VALIDATORS` в настройках Django отсутствует — он никогда не применялся бы к SMS-пользователям и создавал бы ложное впечатление о пароле.

Вход происходит в два шага:

```
1. Клиент отправляет номер телефона
        ↓
2. Бэкенд генерирует 4-значный OTP, сохраняет в Redis на 3 минуты
        ↓
3. SMS с кодом уходит на телефон (в DEBUG-режиме код печатается в консоль)
        ↓
4. Клиент отправляет номер + код
        ↓
5. Бэкенд проверяет код в Redis, удаляет его (одноразовый)
        ↓
6. Если пользователя с таким номером нет — создаётся автоматически
        ↓
7. Клиент получает пару JWT-токенов: access + refresh
```

## Эндпоинты

### POST /api/v1/users/auth/request-sms/

Запрашивает отправку SMS с кодом.

**Авторизация:** не нужна

**Лимиты (два уровня):**
- 3 запроса в минуту с одного IP-адреса
- 5 запросов за 10 минут на один номер телефона

**Тело запроса:**
```json
{ "phone": "+77001234567" }
```

**Формат номера:** `+` и от 10 до 15 цифр. Примеры: `+77001234567`, `+79161234567`.

**Ответ 200:**
```json
{ "message": "SMS код отправлен." }
```

**Ответ 400** — если формат номера неверный:
```json
{ "phone": ["Номер телефона должен быть в формате: '+77001234567'."] }
```

**Ответ 503** — если Redis недоступен (OTP нельзя сохранить):
```json
{ "error": "Сервис временно недоступен. Попробуйте позже." }
```

---

### POST /api/v1/users/auth/verify-sms/

Проверяет OTP-код и выдаёт JWT-токены.

**Авторизация:** не нужна

**Лимит:** 5 запросов в минуту с одного IP (throttling)

**Тело запроса:**
```json
{
  "phone": "+77001234567",
  "otp": "4823"
}
```

**Ответ 200:**
```json
{
  "message": "Успешная авторизация",
  "is_new_user": false,
  "user_id": 42,
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Поле `is_new_user: true` означает, что пользователь только что зарегистрировался — клиент может показать экран заполнения профиля.

**Ответ 400** — если код неверный или просрочен:
```json
{ "error": "Неверный или просроченный код." }
```

---

### GET /api/v1/users/profile/

Возвращает профиль текущего пользователя.

**Авторизация:** Bearer JWT (access токен)

**Ответ 200:**
```json
{
  "id": 42,
  "phone": "+77001234567",
  "first_name": "Алихан",
  "last_name": "Сейткали",
  "gender": "male",
  "email": "alikhan@example.com",
  "birthday": "1995-05-20",
  "notifications_enabled": true,
  "notify_events": true,
  "notify_promotions": true,
  "notify_closed_events": true
}
```

---

### PATCH /api/v1/users/profile/

Частичное обновление профиля. `id` и `phone` — только для чтения, изменить нельзя.

**Авторизация:** Bearer JWT (access токен)

**Тело запроса** (все поля необязательны):
```json
{
  "first_name": "Алихан",
  "last_name": "Сейткали",
  "gender": "male",
  "email": "alikhan@example.com",
  "birthday": "1995-05-20",
  "notify_events": false,
  "notify_promotions": true
}
```

**Ответ 200:** обновлённый профиль (та же схема, что у GET).

После успешного PATCH профиль ставится в очередь на отправку в Remarked
(`push_guest_to_remarked`, см. раздел [Remarked — источник истины](#remarked--источник-истины-о-госте) ниже) — синхронно на ответ это не влияет.

## Модель User

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `phone` | string | Номер телефона, уникальный — является логином |
| `first_name` | string | Имя (необязательное) |
| `last_name` | string | Фамилия (необязательное) |
| `gender` | string | Пол: `male`, `female`, `not_specified` (default) |
| `email` | string | Email (необязательный, `blank=True`) |
| `birthday` | date | Дата рождения (необязательная, `null=True`) |
| `remarked_guest_id` | string | `gid` гостя в CRM Remarked; пусто — гость ещё не синхронизирован. Не отдаётся в `UserProfileSerializer`, виден только в Django Admin |
| `is_active` | bool | Активен ли пользователь |
| `is_staff` | bool | Доступ в Django-админку (**не задавать вручную** — синхронизируется с `role`) |
| `role` | string | Роль: `admin`, `hall_manager`, `content_manager` или пусто |
| `notifications_enabled` | bool | Мастер-флаг согласия на push-уведомления |
| `notify_events` | bool | Уведомления о мероприятиях (default: true) |
| `notify_promotions` | bool | Уведомления об акциях (default: true) |
| `notify_closed_events` | bool | Уведомления о закрытых событиях (default: true) |
| `date_joined` | datetime | Дата регистрации |

> Сервисные уведомления (подтверждение/изменение брони, напоминание о визите) не управляются флагами — они всегда доставляются.

## Remarked — источник истины о госте

Модуль `apps/remarked/` (см. `backend/docs/remarked.md`) — тонкие HTTP-клиенты к
CRM Remarked. Профиль пользователя синхронизируется с гостевой карточкой в
Remarked в обе стороны:

```
Логин (VerifySMSView)                    Профиль (PATCH /users/profile/,
    │                                     RegisterDeviceView)
    ├─ get_or_create(phone)                   │
    │                                         ├─ serializer.save()
    ├─ RemarkedGuestService.sync_on_login()   │
    │   ├─ синхронный pull, timeout=3с        ├─ maybe_push_guest_to_remarked()
    │   ├─ найден → перезаписать              │   ├─ remarked_guest_id есть → upsert
    │   │   first_name/last_name/email/       │   │   (customer/create с текущим
    │   │   birthday/gender, сохранить        │   │   состоянием User)
    │   │   remarked_guest_id                 │   ├─ гостя ещё нет, но name+gender
    │   ├─ не найден → ничего не менять       │   │   уже заполнены → создать
    │   └─ сбой Remarked → не роняем логин,   │   │   (первый customer/create,
    │       fallback: sync_guest_from_remarked│   │   сохранить gid в
    │       (та же логика, в Celery)          │   │   remarked_guest_id)
    │                                         │   └─ иначе (профиль неполный
    └─ выдать JWT, ответ клиенту              │       и гостя ещё нет) — не звать
                                               │
                                               └─ push_guest_to_remarked (Celery)
```

### Правило конфликтов: Remarked побеждает

При `sync_on_login`/`sync_guest_from_remarked`, если поле в ответе Remarked
непустое — оно **перезаписывает** локальное значение `first_name`,
`last_name`, `email`, `birthday`, `gender`. Это осознанное решение: Remarked
считается основной CRM, местные правки в самом Remarked (менеджером ресторана)
должны долетать до приложения.

Пустые/отсутствующие в ответе Remarked поля локальные данные **не затирают** —
иначе первый же логин гостя с неполной карточкой в CRM обнулил бы то, что
человек уже успел ввести в приложении. Логика — `apply_guest_data_to_user()`
в `apps/users/services.py`.

### Синхронный pull при логине vs. фоновый push

- **Логин → Remarked (pull, синхронно):** `RemarkedGuestService.sync_on_login()`
  вызывается прямо в `VerifySMSView.post()` с коротким таймаутом (3 с) —
  пользователь должен увидеть подтянутые данные сразу на экране после входа,
  а не через несколько секунд после фонового таска. Сбой (таймаут/сеть/CRM
  недоступна) не роняет логин — вместо этого синхронизация ставится в очередь
  как `sync_guest_from_remarked` (Celery, тот же паттерн, что и
  `SMSService.send_sms` при недоступном Redis/брокере).
- **Профиль → Remarked (push, всегда асинхронно через Celery):**
  `push_guest_to_remarked` вызывается из `UserProfileView.perform_update()`
  после каждого успешного PATCH и из `RegisterDeviceView` в `apps/notifications`
  после регистрации FCM-токена (заодно передаёт его в Remarked как
  `firebase_token`). Условие вызова — в `maybe_push_guest_to_remarked()`.

### `POST /store/customer/create` — подтверждён partial update

Remarked требует непустые `name`/`gender` в каждом вызове `customer/create`.
Проверено живым экспериментом на боевом Remarked (2026-07-08, см.
`backend/docs/remarked.md#проверено-на-боевом-remarked-2026-07-08`):
эндпоинт **не** затирает поля, которых нет в запросе — обновляет только то,
что реально передано. Поэтому `RemarkedMobileClient.create_or_update()`
может спокойно слать только известные приложению поля (как сейчас) — поля,
заполненные вручную в CRM (`comment`, `tags`) или считаемые самим Remarked
(`bonuses`, `amount_spent`), обновлением профиля из приложения не задеваются.

### Административная синхронизация

В Django Admin (`UserAdmin`) есть массовое действие «Синхронизировать с
Remarked» — ставит `sync_guest_from_remarked` в очередь для выбранных
пользователей.

### Синхронизация `role` ↔ `is_staff`

`User.save()` автоматически поддерживает согласованность:

| Ситуация | Результат |
|---|---|
| `role` задан (любое непустое значение) | `is_staff = True` |
| `role` снят, пользователь не суперпользователь | `is_staff = False` |
| `role` снят, `is_superuser = True` | `is_staff` не трогается |

Это означает, что **`is_staff` не нужно и не следует устанавливать вручную** при управлении ролями. Достаточно изменить `role` и вызвать `save()`. Синхронизация работает при любом способе сохранения: через Admin, Management-команды, тесты, прямой вызов `.save()`.

---

### POST /api/v1/users/auth/logout/

Отзывает refresh-токен, помещая его в blacklist. После этого токен нельзя использовать для обновления access.

**Авторизация:** Bearer JWT (access токен)

**Тело запроса:**
```json
{ "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

**Ответ 204:** тело пустое — logout выполнен.

**Ответ 400** — токен невалиден или уже отозван:
```json
{ "error": "Токен недействителен или уже отозван." }
```

**Ответ 401** — не передан или недействителен access-токен в заголовке.

> **Важно:** access-токен продолжает работать до истечения своего TTL (30 мин в проде). Blacklist инвалидирует только возможность получить новый access через refresh. Клиент должен удалить оба токена из `flutter_secure_storage` после logout.

---

### POST /api/v1/users/auth/token/refresh/

Обновляет access-токен по действующему refresh-токену. Позволяет не проходить SMS-флоу заново при истечении access-токена.

**Авторизация:** не нужна

**Тело запроса:**
```json
{ "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

**Ответ 200:**
```json
{ "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

**Ответ 401** — если refresh-токен недействителен или просрочен:
```json
{ "detail": "Token is invalid or expired", "code": "token_not_valid" }
```

**Ответ 400** — если поле `refresh` не передано.

---

## JWT-токены

| Токен | Время жизни (dev) | Время жизни (prod) |
|---|---|---|
| `access` | 1 день | 30 минут |
| `refresh` | 7 дней | 7 дней |

Для обновления access-токена используй: `POST /api/v1/users/auth/token/refresh/`.

## Файлы модуля

```
apps/users/
├── models.py       # Кастомная модель User (AbstractBaseUser)
├── serializers.py  # RequestSMSSerializer, VerifySMSSerializer, LogoutSerializer, UserProfileSerializer
├── views.py        # RequestSMSView, VerifySMSView, LogoutView, UserProfileView
├── services.py     # SMSService, RemarkedGuestService, apply_guest_data_to_user, maybe_push_guest_to_remarked
├── tasks.py        # send_sms_task, sync_guest_from_remarked, push_guest_to_remarked
├── throttles.py    # PhoneSMSThrottle — троттлинг по номеру телефона (5 запросов / 10 мин)
└── urls.py         # Маршруты /api/v1/users/...
```

## SMS-сервис

Файл: `apps/users/services.py` — класс `SMSService`.

**Схема работы в боевом режиме (`DEBUG=False`):**

```
RequestSMSView.post()
    │
    ├─ SMSService.send_sms(phone)          ← синхронно, не блокирует worker
    │       │
    │       ├─ generate_otp()              ← генерация 4-значного кода
    │       ├─ cache.set(otp, ttl=180)     ← сохранение в Redis
    │       └─ send_sms_task.delay(phone, otp)  ← постановка в очередь Celery
    │
    └─ return 200 OK                       ← ответ клиенту без ожидания SMS

Celery worker (фоново):
    send_sms_task(phone, otp)
        └─ requests.post(SMS_PROVIDER_URL, timeout=10)
               ├─ 200 OK → успех
               └─ ошибка → retry (до 3 раз, пауза 30 сек)
```

| Режим | Поведение |
|---|---|
| `DEBUG=True` | Код печатается в консоль сервера, Celery не вызывается, SMS не отправляется |
| `DEBUG=False` | OTP сохраняется в Redis, HTTP-запрос к провайдеру — в Celery-таске асинхронно |

**Переменные окружения для боевого режима:**
```
SMS_PROVIDER_URL=https://smsc.ru/sys/send.php
SMS_LOGIN=your_login
SMS_PASSWORD=your_password
```

При ошибке сети или статусе не 200 провайдера — Celery-таска повторяет попытку до 3 раз с паузой 30 секунд. OTP в Redis сохранён до вызова таски — клиент получает 200 немедленно.

## Троттлинг

### Глобальный rate limiting (все эндпоинты)

Все API-эндпоинты автоматически защищены глобальными лимитами через DRF:

| Тип пользователя | Лимит | Ключ |
|---|---|---|
| Анонимный (по IP) | 60 запросов / минута | `AnonRateThrottle` |
| Аутентифицированный (по user_id) | 300 запросов / минута | `UserRateThrottle` |

При превышении лимита — `HTTP 429 Too Many Requests`.

Настраивается в `config/settings/base.py` (секция `DEFAULT_THROTTLE_RATES`). В тестах отключено через `config/settings/test.py`.

### SMS-эндпоинты (дополнительные лимиты)

Эндпоинт `POST /api/v1/users/auth/request-sms/` дополнительно защищён на двух уровнях:

| Уровень | Ключ в Redis | Лимит |
|---|---|---|
| По IP (ScopedRateThrottle) | стандартный DRF-ключ по IP | 3 запроса / 1 минута |
| По номеру телефона (PhoneSMSThrottle) | `throttle_sms_request_phone_{phone}` | 5 запросов / 10 минут |

Если превышен любой из лимитов — возвращается `HTTP 429 Too Many Requests`.

Двухуровневый подход защищает от:
- **Спама с одного IP** — первый уровень (IP-счётчик)
- **Распределённых атак** — разные IP атакуют один номер, первый уровень не срабатывает, но второй блокирует по номеру

## JWT Blacklist

Приложение `rest_framework_simplejwt.token_blacklist` подключено в `INSTALLED_APPS` и хранит отозванные токены в таблице `token_blacklist_blacklistedtoken`.

**Ротация refresh-токенов** (`ROTATE_REFRESH_TOKENS = True`, `BLACKLIST_AFTER_ROTATION = True`):
- При каждом вызове `POST /api/v1/users/auth/token/refresh/` выдаётся новый refresh-токен, а старый автоматически попадает в blacklist.
- Это предотвращает повторное использование перехваченного refresh-токена.

**Явный logout** (`POST /api/v1/users/auth/logout/`):
- Клиент передаёт refresh-токен; сервер записывает его в blacklist.
- Последующие попытки обновить access через этот refresh вернут 401.
- access-токен остаётся рабочим до конца своего TTL (30 мин в проде) — это нормальное поведение для stateless JWT.

## Важные нюансы

- OTP хранится в Redis под ключом `otp_<номер_телефона>`. После успешной проверки удаляется.
- В `DEBUG=True` SMS не отправляется — код печатается в консоль сервера. Это намеренно.
- Смена номера телефона через PATCH недоступна — это поле `read_only`. Смена номера требует отдельного OTP-флоу.
- `create_superuser` для Django-админки принимает пароль, обычные пользователи входят без пароля.
- После logout клиент обязан удалить оба токена из `flutter_secure_storage` и перенаправить на экран входа.

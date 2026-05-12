# Модуль: events

Отвечает за мероприятия (афиша), новости ресторана и запись пользователей на мероприятия.

## Структура данных

```
Event (Мероприятие)
    └── EventReservation (Запись на мероприятие)
            └── User (Пользователь)

News (Новость) — независимая сущность
```

## Эндпоинты

### GET /api/events/upcoming/

Предстоящие мероприятия — дата проведения в будущем, отсортированы от ближайшего.

**Авторизация:** не нужна

**Query-параметры:** `page`, `page_size` (по умолчанию 20, максимум 100)

**Ответ 200:**
```json
{
  "count": 5,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 3,
      "title": "Jazz Night",
      "description": "Живая джазовая музыка и авторские коктейли",
      "date_time": "2026-06-20T20:00:00+06:00",
      "image": "/media/events/images/jazz.jpg",
      "format": "open",
      "price": null,
      "is_active": true,
      "created_at": "2026-05-01T10:00:00+06:00"
    }
  ]
}
```

---

### GET /api/events/archived/

Прошедшие мероприятия — дата проведения в прошлом, отсортированы от самого свежего.

**Авторизация:** не нужна

**Query-параметры:** `page`, `page_size`

Схема ответа аналогична `upcoming`.

---

### GET /api/events/news/

Новости ресторана, отсортированные от самой свежей.

**Авторизация:** не нужна

**Query-параметры:** `page`, `page_size`

**Ответ 200:**
```json
{
  "count": 12,
  "next": "http://localhost:8000/api/events/news/?page=2",
  "previous": null,
  "results": [
    {
      "id": 7,
      "title": "Новое летнее меню",
      "content": "Мы обновили меню — теперь у нас есть...",
      "image": "/media/news/images/summer.jpg",
      "created_at": "2026-05-10T12:00:00+06:00"
    }
  ]
}
```

Поле `image` может быть `null` — новость без картинки допустима.

---

### POST /api/events/reservations/create/

Записывает текущего пользователя на мероприятие.

**Авторизация:** Bearer JWT (обязательна)

**Тело запроса:**
```json
{
  "event": 3,
  "guests_count": 2
}
```

`guests_count` — количество человек включая самого пользователя. По умолчанию 1.

**Ответ 201:**
```json
{
  "id": 15,
  "event": 3,
  "event_details": {
    "id": 3,
    "title": "Jazz Night",
    "description": "...",
    "date_time": "2026-06-20T20:00:00+06:00",
    "image": "/media/events/images/jazz.jpg",
    "format": "open",
    "price": null,
    "is_active": true,
    "created_at": "2026-05-01T10:00:00+06:00"
  },
  "guests_count": 2,
  "created_at": "2026-05-11T14:30:00+06:00"
}
```

**Ответ 400** — повторная запись на то же мероприятие:
```json
{ "non_field_errors": ["Вы уже записаны на это мероприятие."] }
```

После успешной записи пользователь автоматически получает **push-уведомление** (если устройство зарегистрировано).

---

### GET /api/events/reservations/my/

Список всех записей текущего пользователя на мероприятия.

**Авторизация:** Bearer JWT (обязательна)

**Query-параметры:** `page`, `page_size`

**Ответ 200:** список объектов той же схемы, что у POST-ответа выше.

## Модели

### Event

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `title` | string | Заголовок мероприятия |
| `description` | text | Описание |
| `date_time` | datetime | Дата и время проведения |
| `image` | image | Обложка (обязательная) |
| `format` | string | Формат: `open` (открытое) или `closed` (закрытое). По умолчанию `open` |
| `price` | decimal | Цена входа в тенге (необязательное, `null` = вход свободный) |
| `is_active` | bool | Скрытые мероприятия (`false`) не попадают в API |
| `created_at` | datetime | Дата создания записи |

### News

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `title` | string | Заголовок новости |
| `content` | text | Текст новости |
| `image` | image | Изображение (необязательное, может быть `null`) |
| `created_at` | datetime | Дата публикации |

### EventReservation

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `event` | FK → Event | Мероприятие |
| `user` | FK → User | Пользователь (проставляется из токена, не передаётся в запросе) |
| `guests_count` | int | Количество гостей включая пользователя (по умолчанию 1) |
| `created_at` | datetime | Дата и время бронирования |

Пара `(event, user)` уникальна — один пользователь не может записаться дважды на одно мероприятие (защита на уровне БД и сериализатора).

### Поля только для персонала (EventReservationStaffSerializer)

Для менеджера зала доступен `EventReservationStaffSerializer`, который добавляет:

| Поле | Тип | Описание |
|---|---|---|
| `guest_name` | string | Имя гостя (first_name + last_name из профиля; или телефон если имя не заполнено) |
| `guest_phone` | string | Телефон гостя из профиля (`user.phone`) |

Эти поля также отображаются в Django-админке (`EventReservation → list_display`).

## Push-уведомления

При создании `EventReservation` автоматически уходит push через Celery:

- **Заголовок:** "Вы записаны на мероприятие"
- **Тело:** "Jazz Night — 20.06.2026 20:00"
- **data:** `{ "event_id": "3", "reservation_id": "15" }`

## Файлы модуля

```
apps/events/
├── models.py       # Event, News, EventReservation
├── serializers.py  # EventSerializer, NewsSerializer, EventReservationSerializer, EventReservationStaffSerializer
├── views.py        # 5 view-классов
├── signals.py      # push при создании EventReservation
├── apps.py         # подключение signals в ready()
└── urls.py         # Маршруты /api/events/...
```

## Важные нюансы

- Разделение на `upcoming` / `archived` происходит по текущему времени сервера (`timezone.now()`). Часовой пояс сервера — `Asia/Almaty`.
- Мероприятие с `is_active=False` не появится ни в upcoming, ни в archived — управляется через Django-админку.
- Поле `user` в `EventReservationSerializer` — `read_only`. Пользователь определяется по JWT-токену в `perform_create`.
- Удаления записи на мероприятие через API нет — только через Django-админку.

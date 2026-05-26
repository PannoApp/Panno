# Модуль: events

Отвечает за мероприятия (афиша), новости ресторана, запись пользователей на мероприятия и фотоотчёты прошедших событий.

## Структура данных

```
Event (Мероприятие)
    ├── EventReservation (Запись на мероприятие)
    │       └── User (Пользователь)
    └── EventPhotoReport (Фото фотоотчёта)

News (Новость) — независимая сущность
```

## Эндпоинты

### GET /api/v1/events/upcoming/

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
      "image": "https://piligrim.kz/media/events/images/a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6.jpg",
      "format": "open",
      "price": null,
      "is_active": true,
      "created_at": "2026-05-01T10:00:00+06:00"
    }
  ]
}
```

---

### GET /api/v1/events/archived/

Прошедшие мероприятия — дата проведения в прошлом, отсортированы от самого свежего.

**Авторизация:** не нужна

**Query-параметры:** `page`, `page_size`

Схема ответа аналогична `upcoming`.

---

### GET /api/v1/events/news/

Новости ресторана, отсортированные от самой свежей.

**Авторизация:** не нужна

**Query-параметры:** `page`, `page_size`

**Ответ 200:**
```json
{
  "count": 12,
  "next": "http://localhost:8000/api/v1/events/news/?page=2",
  "previous": null,
  "results": [
    {
      "id": 7,
      "title": "Новое летнее меню",
      "content": "Мы обновили меню — теперь у нас есть...",
      "image": "https://piligrim.kz/media/news/images/c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6.jpg",
      "created_at": "2026-05-10T12:00:00+06:00"
    }
  ]
}
```

Поле `image` может быть `null` — новость без картинки допустима.

---

### POST /api/v1/events/reservations/create/

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
    "image": "https://piligrim.kz/media/events/images/a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6.jpg",
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

### GET /api/v1/events/reservations/my/

Список всех записей текущего пользователя на мероприятия.

**Авторизация:** Bearer JWT (обязательна)

**Query-параметры:** `page`, `page_size`

**Ответ 200:** список объектов той же схемы, что у POST-ответа выше.

---

### GET /api/v1/events/{event_id}/photo-report/

Фотоотчёт прошедшего мероприятия — список фотографий, загруженных после события.

**Авторизация:** не нужна

**Параметры пути:** `event_id` — ID мероприятия

**Ответ 200:**
```json
[
  {
    "id": 1,
    "image": "https://cdn.example.com/media/events/reports/d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6.jpg",
    "order": 0
  },
  {
    "id": 2,
    "image": "https://cdn.example.com/media/events/reports/e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6.jpg",
    "order": 1
  }
]
```

**Пустой список** возвращается в двух случаях:
- Мероприятие ещё не прошло (`date_time` в будущем)
- Фотоотчёт не загружен или `event_id` не существует

Ответ — плоский массив (не пагинированный), результаты отсортированы по полю `order`, затем по дате загрузки.

Фотографии загружаются через Django-админку: страница мероприятия → inline-секция «Фотоотчёт».

**Интеграция с EventSerializer:** поле `has_photo_report` в ответах `/upcoming/` и `/archived/` возвращает `true`, если для мероприятия уже есть хотя бы одно фото. Flutter-клиент использует это поле чтобы решить, отображать ли секцию фотоотчёта без лишнего запроса.

## Модели

### Event

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `title` | string | Заголовок мероприятия |
| `description` | text | Описание |
| `date_time` | datetime | Дата и время проведения |
| `image` | image | Обложка (обязательная). Автоматически обрезается до 16:9 и конвертируется в JPEG при загрузке. API возвращает **абсолютный URL**. При замене или удалении объекта старый файл удаляется из хранилища автоматически (django-cleanup). |
| `format` | string | Формат: `open` (открытое) или `closed` (закрытое). По умолчанию `open` |
| `price` | decimal | Цена входа в тенге (необязательное, `null` = вход свободный) |
| `max_places` | int | Количество разрешенных мест (по умолчанию `0` — без ограничений) |
| `occupied_places` | int | Вычисляемое поле: количество уже занятых мест (сумма гостей во всех записях на это мероприятие) |
| `is_active` | bool | Скрытые мероприятия (`false`) не попадают в API |
| `created_at` | datetime | Дата создания записи |
| `has_photo_report` | bool | `true` если к мероприятию загружен хотя бы один фотоотчёт (вычисляемое поле) |

### EventPhotoReport

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `event` | FK → Event | Мероприятие (CASCADE при удалении) |
| `image` | image | Фотография (папка: `events/reports/`, имя файла — UUID hex, расширение оригинала сохраняется). Не обрезается — отображается fullscreen с `BoxFit.contain`. API возвращает **абсолютный URL**. При замене или удалении объекта старый файл удаляется из хранилища автоматически (django-cleanup). |
| `order` | int | Порядок отображения в галерее (по умолчанию 0) |
| `uploaded_at` | datetime | Дата загрузки (auto) |

Результаты сортируются по `order ASC`, затем `uploaded_at ASC`. Управление исключительно через Django-админку (inline в `EventAdmin`).

### News

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `title` | string | Заголовок новости |
| `content` | text | Текст новости |
| `image` | image | Изображение (необязательное, может быть `null`). Автоматически обрезается до 16:9 и конвертируется в JPEG при загрузке. API возвращает **абсолютный URL** или `null`. При замене или удалении объекта старый файл удаляется из хранилища автоматически (django-cleanup). |
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

---

## Admin Events CRUD (Staff Only)

Полный CRUD мероприятий для сотрудников. Видит **все** мероприятия, включая неактивные (`is_active=False`).

**Авторизация:** `Bearer <access_token>`, пользователь должен иметь роль `content_manager`, `manager`, или `admin` (`is_staff=True`).

| Метод | URL | Описание |
|---|---|---|
| `GET` | `/api/v1/events/admin/events/` | Список всех мероприятий |
| `POST` | `/api/v1/events/admin/events/` | Создать мероприятие |
| `GET` | `/api/v1/events/admin/events/{id}/` | Детали мероприятия |
| `PUT` | `/api/v1/events/admin/events/{id}/` | Полное обновление |
| `PATCH` | `/api/v1/events/admin/events/{id}/` | Частичное обновление |
| `DELETE` | `/api/v1/events/admin/events/{id}/` | Удалить мероприятие |

Пагинация отключена — возвращается плоский массив, отсортированный по убыванию `date_time`.

### Поля StaffEventSerializer

| Поле | Тип | R/W | Обязательное | Описание |
|---|---|---|---|---|
| `id` | int | read | — | Первичный ключ |
| `title` | string | write | да | Заголовок мероприятия |
| `description` | text | write | да | Описание |
| `date_time` | datetime | write | да | Дата и время проведения |
| `image` | file | write | при создании | Обложка (multipart). При обновлении необязательна |
| `image_url` | string | read | — | Абсолютный URL текущей обложки |
| `format` | string | write | нет | `open` или `closed` (по умолчанию `open`) |
| `price` | decimal | write | нет | Цена в тенге; `null` = вход свободный |
| `is_active` | bool | write | нет | `false` — мероприятие скрыто из публичных эндпоинтов |
| `max_places` | int | write | нет | Лимит мест (по умолчанию `0` — без ограничений) |
| `occupied_places` | int | read | — | Вычисляемое: сумма `guests_count` всех бронирований |
| `created_at` | datetime | read | — | Дата создания |

### Content-Type

- `multipart/form-data` — при создании и при обновлении с новой обложкой
- `application/json` — для `PATCH` без смены изображения

### Примеры

**Создать мероприятие:**
```bash
curl -X POST https://piligrim.kz/api/v1/events/admin/events/ \
  -H "Authorization: Bearer <access_token>" \
  -F "title=Jazz Night" \
  -F "description=Живая джазовая музыка" \
  -F "date_time=2026-06-20T20:00:00+06:00" \
  -F "format=open" \
  -F "price=" \
  -F "image=@/path/to/cover.jpg"
```

**Скрыть мероприятие (PATCH без файла):**
```bash
curl -X PATCH https://piligrim.kz/api/v1/events/admin/events/3/ \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"is_active": false}'
```

### Ошибки

| Код | Причина |
|---|---|
| `400` | Нет `image` при создании; недопустимое значение `format` |
| `401` | Токен не передан или истёк |
| `403` | Пользователь не является staff |
| `404` | Мероприятие не найдено |

---

## Admin News CRUD (Staff Only)

Полный CRUD новостей для сотрудников.

**Авторизация:** аналогично Admin Events — `Bearer <access_token>`, `is_staff=True`.

| Метод | URL | Описание |
|---|---|---|
| `GET` | `/api/v1/events/admin/news/` | Список всех новостей |
| `POST` | `/api/v1/events/admin/news/` | Создать новость |
| `GET` | `/api/v1/events/admin/news/{id}/` | Детали новости |
| `PUT` | `/api/v1/events/admin/news/{id}/` | Полное обновление |
| `PATCH` | `/api/v1/events/admin/news/{id}/` | Частичное обновление |
| `DELETE` | `/api/v1/events/admin/news/{id}/` | Удалить новость |

Пагинация отключена — плоский массив, отсортированный по убыванию `created_at`.

### Поля StaffNewsSerializer

| Поле | Тип | R/W | Обязательное | Описание |
|---|---|---|---|---|
| `id` | int | read | — | Первичный ключ |
| `title` | string | write | да | Заголовок |
| `content` | text | write | да | Текст новости |
| `image` | file | write | нет | Изображение (multipart). Может быть `null` |
| `image_url` | string | read | — | Абсолютный URL изображения или `null` |
| `created_at` | datetime | read | — | Дата публикации |

> В отличие от мероприятий, `image` у новости **необязательна** — как при создании, так и при обновлении.

### Content-Type

- `multipart/form-data` — при создании/обновлении с изображением
- `application/json` — для `PATCH` без смены изображения

### Ошибки

| Код | Причина |
|---|---|
| `400` | Ошибка валидации полей |
| `401` | Токен не передан или истёк |
| `403` | Пользователь не является staff |
| `404` | Новость не найдена |

---

## Файлы модуля

```
apps/events/
├── models.py       # Event, News, EventReservation, EventPhotoReport
├── serializers.py  # EventSerializer (+has_photo_report), NewsSerializer,
│                   # EventReservationSerializer, EventReservationStaffSerializer,
│                   # EventPhotoReportSerializer,
│                   # StaffEventSerializer, StaffNewsSerializer
├── views.py        # UpcomingEventsListView, ArchivedEventsListView, NewsListView,
│                   # EventReservationCreateView, UserEventReservationsListView,
│                   # EventPhotoReportListView,
│                   # StaffEventViewSet, StaffNewsViewSet
├── signals.py      # push при создании EventReservation; инвалидация кэша
├── apps.py         # подключение signals в ready()
└── urls.py         # Маршруты /api/v1/events/... + router для admin/events, admin/news
```

## Важные нюансы

- Разделение на `upcoming` / `archived` происходит по текущему времени сервера (`timezone.now()`). Часовой пояс сервера — `Asia/Almaty`.
- Мероприятие с `is_active=False` не появится ни в upcoming, ни в archived — управляется через Django-админку.
- Поле `user` в `EventReservationSerializer` — `read_only`. Пользователь определяется по JWT-токену в `perform_create`.
- Удаления записи на мероприятие через API нет — только через Django-админку.

## Идемпотентность

`POST /api/v1/events/reservations/create/` требует заголовок `Idempotency-Key` со значением UUID v4. Мобильный клиент генерирует UUID v4 один раз при начале заполнения формы / попытке отправки и переиспользует тот же UUID при всех сетевых retry-ях для этой формы.

**Поведение:**
- Первый запрос с ключом — создание записи, ответ кешируется в Redis на 24 часа.
- Повторный запрос с тем же ключом — возвращает закешированный ответ без дублирования.
- Ошибка 400 (например, несуществующий `event`) тоже кешируется — повтор вернёт тот же 400.
- Запрос без заголовка или с невалидным значением → `400 Bad Request`.

```http
POST /api/v1/events/reservations/create/
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

## Кэширование публичных эндпоинтов

Публичные эндпоинты событий и новостей кэшируют ответы в Redis.

| Эндпоинт | Ключ кэша | TTL | Инвалидация |
|---|---|---|---|
| `GET /api/v1/events/upcoming/` | `events_upcoming:{version}:{query_string}` | 60 сек | `post_save` / `post_delete` на `Event` |
| `GET /api/v1/events/archived/` | `events_archived:{version}:{query_string}` | 60 сек | `post_save` / `post_delete` на `Event` |
| `GET /api/v1/events/news/` | `events_news:{version}:{query_string}` | 300 сек | `post_save` / `post_delete` на `News` |

**Короткий TTL для событий** — список предстоящих и прошедших событий зависит от `timezone.now()`. TTL=60 секунд гарантирует, что событие «переедет» из upcoming в archived не позже чем через минуту после его наступления. Когда менеджер изменяет событие вручную — сигнал инкрементирует версию, инвалидация мгновенная.

Сигналы инвалидации добавлены в `apps/events/signals.py`.

---

## Создание новостей и мероприятий через Telegram-бот

Контент-менеджеры (`content_manager`) и администраторы (`admin`) могут создавать новости и мероприятия непосредственно через Telegram-бот с помощью интерактивного диалога (конечного автомата).

### Создание новости (`News`)

Для запуска процесса отправьте команду `/createnews` или нажмите кнопку **📰 Создать новость**. Бот поочередно запросит:
1. **Заголовок новости** (текст).
2. **Текст новости** (текст).
3. **Изображение** (фото).
   > ⚠️ **Важно по фото:** Отправленная фотография в будущем может быть отредактирована или заменена только в панели управления (админке) Django. Для корректного отображения в мобильном приложении подготовьте изображение с соотношением сторон **16:9** (например, 1920x1080).
   > Этот шаг можно пропустить, нажав кнопку `⏭ Пропустить` или отправив `/skip`.
4. **Подтверждение**: Превью новости с кнопками `✅ Опубликовать` и `❌ Отменить`.

При подтверждении бот скачает изображение через Telegram Bot API и создаст объект `News` в базе данных.

### Создание мероприятия (`Event`)

Для запуска процесса отправьте команду `/createevent` или нажмите кнопку **📅 Создать мероприятие**. Бот поочередно запросит:
1. **Заголовок мероприятия** (текст).
2. **Описание** (текст).
3. **Дата и время проведения** (текст в формате `ДД.ММ.ГГГГ ЧЧ:ММ`, например, `25.05.2026 19:00`). Валидируется при вводе.
4. **Формат** (инлайн-кнопки `Открытое` или `Закрытое`).
5. **Цена входа** (число в тенге, либо кнопка `Вход свободный`).
6. **Обложка мероприятия** (фото, обязательное поле).
   > ⚠️ **Важно по фото:** Обложка обязательна для мероприятия. Изменить или удалить её позже можно только в панели управления (админке) Django. Подготовьте изображение с соотношением сторон **16:9** (например, 1920x1080).
7. **Подтверждение**: Превью мероприятия с кнопками `✅ Создать` и `❌ Отменить`.

При подтверждении бот скачает обложку через Telegram Bot API и создаст объект `Event` в базе данных.


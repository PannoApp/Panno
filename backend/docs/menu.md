# Модуль: menu

Отвечает за хранение и отдачу меню ресторана: категории, блюда, теги, аллергены.

## Локальный демо-контент

После `migrate` на чистой БД:

```bash
docker compose exec backend python manage.py seed_demo_content --force
```

Создаёт категории, 10 блюд с фото и описаниями (`apps/menu/seed_data/images/`), фото интерьера и hero-слайды (`apps/core/seed_data/interior/`). Повтор без `--force` пропускает, если меню уже есть.

## Структура данных

```
Category (Категория)
    └── Dish (Блюдо)
            ├── Tag (Тег, many-to-many)        — например: "Острое", "Вегетарианское"
            └── Allergen (Аллерген, many-to-many) — например: "Глютен", "Орехи"
```

## Эндпоинты

### GET /api/v1/menu/feed/

Видеолента блюд с курсорной пагинацией. Возвращает только активные блюда с `video_status=ready`.

**Авторизация:** не нужна

**Query-параметры:**

| Параметр | Тип | Описание |
|---|---|---|
| `cursor` | string | Непрозрачный курсор из поля `next` предыдущего ответа |

**Ответ 200:**
```json
{
  "next": "http://localhost:8000/api/v1/menu/feed/?cursor=cD0y",
  "previous": null,
  "results": [
    {
      "id": 3,
      "name": "Стейк Рибай",
      "video_url": "http://localhost:8000/media/dishes/videos/processed/a3f8c2d1e0b74f6a9c2e1d0b3f8a7c2d.mp4",
      "video_status": "ready",
      ...
    }
  ]
}
```

Пагинация — курсорная (`VideoCursorPagination`): page_size=5, сортировка по `id`.  
Курсор гарантирует стабильный обход при одновременных вставках (в отличие от page-number).  
Кэш **не применяется** — курсор кодирует позицию конкретного запроса.

---

### GET /api/v1/menu/categories/

Возвращает все категории, отсортированные по полю `order`.

**Авторизация:** не нужна

**Ответ 200:**
```json
[
  { "id": 1, "name": "Горячие блюда", "order": 1 },
  { "id": 2, "name": "Салаты", "order": 2 },
  { "id": 3, "name": "Напитки", "order": 3 }
]
```

Пагинации нет — возвращаются все категории сразу.

---

### GET /api/v1/menu/tags/

Возвращает все теги блюд, отсортированные по имени.

**Авторизация:** не нужна

**Ответ 200:**
```json
[
  { "id": 1, "name": "Вегетарианское" },
  { "id": 3, "name": "Острое" },
  { "id": 2, "name": "Хит" }
]
```

Пагинации нет — возвращаются все теги сразу. Кэш — 1 час, инвалидируется при изменении тега в админке.

---

### GET /api/v1/menu/dishes/

Возвращает список активных блюд (`is_active=True`).

**Авторизация:** не нужна

**Query-параметры:**

| Параметр | Тип | Описание |
|---|---|---|
| `category_id` | int | Фильтр по ID категории |
| `tag_ids` | string | Фильтр по тегам (ID через запятую, пример: `?tag_ids=1,3`). Блюдо должно иметь хотя бы один из указанных тегов |
| `search` | string | Поиск по названию и описанию блюда (регистронезависимый, пример: `?search=стейк`) |
| `page` | int | Номер страницы |
| `page_size` | int | Размер страницы (по умолчанию **5**, максимум **20**) |

Пагинация — формат «видеолента»: маленький page_size, чтобы блюда подгружались порциями при скролле.

**Ответ 200:**
```json
{
  "count": 42,
  "next": "http://localhost:8000/api/v1/menu/dishes/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "Стейк Рибай",
      "description": "Мраморная говядина, степень прожарки на выбор",
      "price": "4500.00",
      "category": { "id": 1, "name": "Горячие блюда", "order": 1 },
      "tags": [{ "id": 2, "name": "Хит" }],
      "allergens": [{ "id": 1, "name": "Глютен" }],
      "image": "http://localhost:8000/media/dishes/images/b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6.jpg",
      "video_url": "http://localhost:8000/media/dishes/videos/processed/f1e2d3c4b5a6f7e8d9c0b1a2f3e4d5c6.mp4",
      "video_status": "ready",
      "weight": 350,
      "story": "Рибай — классика американского стейкхауса...",
      "is_active": true
    }
  ]
}
```

## Модели

### Category

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `name` | string | Название категории |
| `order` | int | Порядок отображения (меньше = выше) |

### Tag

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `name` | string | Название тега (например: «Острое», «Хит», «Новинка») |

### Allergen

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `name` | string | Название аллергена (например: «Глютен», «Лактоза», «Орехи») |

### Dish

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Первичный ключ |
| `name` | string | Название блюда |
| `description` | text | Описание блюда |
| `price` | decimal | Цена (до 10 знаков, 2 десятичных) |
| `category` | FK → Category | Категория блюда |
| `tags` | M2M → Tag | Теги (может быть пустым) |
| `allergens` | M2M → Allergen | Аллергены (может быть пустым) |
| `image` | image | Фото блюда (обязательное). Автоматически обрезается до 16:9 и конвертируется в JPEG при сохранении. Имя файла — UUID hex (32 символа), оригинальное имя не сохраняется. API возвращает **абсолютный URL**. При замене или удалении объекта старый файл удаляется из хранилища автоматически (django-cleanup). |
| `video` | file | Оригинальное видео, загружаемое администратором (необязательное). В API не возвращается. При замене или удалении объекта старый файл удаляется автоматически (django-cleanup). |
| `video_processed` | file | Транскодированное видео H.264/720×1280 (заполняется Celery, не редактируется вручную). При замене новым обработанным видео старый файл удаляется автоматически (django-cleanup). |
| `video_status` | enum | Статус обработки: `pending` / `processing` / `ready` / `failed`. Flutter воспроизводит видео только при `ready`. |
| `weight` | int | Вес порции в граммах (необязательное) |
| `story` | text | История блюда — для расширенной карточки (необязательное) |
| `is_active` | bool | Если `false` — блюдо скрыто из API |

#### Жизненный цикл видео

```
Администратор загружает video
        ↓
  post_save сигнал
        ↓
  video_status = pending
  → Celery: process_dish_video.delay(dish_id)
        ↓
  video_status = processing
  FFmpeg: scale 720×1280, H.264 CRF=28, AAC 128k, faststart
        ↓ (успех)          ↓ (ошибка, max 2 retry)
  video_processed = файл   video_status = failed
  video_status = ready
```

`video_url` в ответе API — абсолютный URL к `video_processed`. Возвращает `null`, пока видео не готово.

## Admin Dish CRUD (Staff Only)

Управление блюдами для пользователей с `is_staff=True`. Видит все блюда включая неактивные (`is_active=False`).

**Авторизация:** `Authorization: Bearer <access_token>` + `is_staff=true`

**Base URL:** `/api/v1/menu/admin/dishes/`

### Маршруты

| Метод | URL | Действие |
|---|---|---|
| `GET` | `/api/v1/menu/admin/dishes/` | Список всех блюд (без пагинации) |
| `POST` | `/api/v1/menu/admin/dishes/` | Создать блюдо |
| `GET` | `/api/v1/menu/admin/dishes/{id}/` | Получить блюдо по ID |
| `PUT` | `/api/v1/menu/admin/dishes/{id}/` | Полное обновление блюда |
| `PATCH` | `/api/v1/menu/admin/dishes/{id}/` | Частичное обновление блюда |
| `DELETE` | `/api/v1/menu/admin/dishes/{id}/` | Удалить блюдо |

**Content-Type:**
- `POST`, `PUT`, `PATCH` с изображением — `multipart/form-data`
- `PATCH` без изображения — `application/json`

---

### Поля StaffDishSerializer

| Поле | Тип | Режим | Обязательность | Описание |
|---|---|---|---|---|
| `id` | int | read | — | Первичный ключ (авто) |
| `name` | string | read/write | required | Название блюда |
| `description` | text | read/write | optional | Описание блюда |
| `price` | decimal | read/write | required | Цена (строка: `"4500.00"`) |
| `category` | int | read/write | required | ID категории (FK) |
| `tags` | int[] | read/write | optional | Список ID тегов (M2M) |
| `allergens` | int[] | read/write | optional | Список ID аллергенов (M2M) |
| `image` | file | write | required при создании | Фото блюда (multipart) |
| `image_url` | string | read | — | Абсолютный URL фото |
| `weight` | int | read/write | optional | Вес порции в граммах |
| `story` | text | read/write | optional | История блюда |
| `is_active` | bool | read/write | optional | Видимость блюда в публичном API (default: `true`) |

> `video` и `video_processed` через Staff API не управляются — только через Django Admin.

---

### Примеры

**Создать блюдо (`multipart/form-data`):**
```bash
curl -X POST http://localhost:8000/api/v1/menu/admin/dishes/ \
  -H "Authorization: Bearer <access_token>" \
  -F "name=Стейк Рибай" \
  -F "description=Мраморная говядина" \
  -F "price=4500.00" \
  -F "category=1" \
  -F "tags=2" \
  -F "allergens=1" \
  -F "weight=350" \
  -F "is_active=true" \
  -F "image=@/path/to/photo.jpg"
```

**Частичное обновление (`application/json`):**
```bash
curl -X PATCH http://localhost:8000/api/v1/menu/admin/dishes/1/ \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"price": "5000.00", "is_active": false}'
```

---

### Коды ошибок

| Код | Причина |
|---|---|
| `400 Bad Request` | Нет `image` при создании (`{"image": "Фото обязательно при создании блюда."}`) |
| `403 Forbidden` | Пользователь не авторизован или `is_staff=False` |
| `404 Not Found` | Блюдо с указанным `id` не существует |

---

## Allergens

### GET /api/v1/menu/allergens/

Возвращает все аллергены, отсортированные по имени.

**Авторизация:** не нужна

**Ответ 200:**
```json
[
  { "id": 1, "name": "Глютен" },
  { "id": 2, "name": "Лактоза" },
  { "id": 3, "name": "Орехи" }
]
```

Пагинации нет — возвращаются все аллергены сразу. Кэш не применяется.

---

## Файлы модуля

```
apps/menu/
├── models.py       # Category, Tag, Allergen, Dish (+ VideoStatus enum)
├── serializers.py  # CategorySerializer, TagSerializer, AllergenSerializer, DishSerializer
├── views.py        # CategoryListView, AllergenListView, TagListView, DishListView, VideoFeedView, StaffDishViewSet
├── filters.py      # DishFilter (category_id, tag_ids, search)
├── tasks.py        # process_dish_video — Celery-задача FFmpeg транскодирования
├── signals.py      # trigger_video_processing, кэш-инвалидация
└── urls.py         # /categories/, /tags/, /allergens/, /dishes/, /feed/, /admin/dishes/
```

## Кэширование

Публичные эндпоинты меню кэшируют результаты в Redis.

| Эндпоинт | Стратегия | TTL | Инвалидация |
|---|---|---|---|
| `GET /api/v1/menu/categories/` | Единый ключ `menu_categories` | 3600 сек | `post_save` / `post_delete` на `Category` |
| `GET /api/v1/menu/dishes/` | Версионный ключ `menu_dishes:{version}:{query_string}` | 300 сек | Инкремент `menu_dishes_cache_version` при изменении `Dish`, `Category`, `Tag`, `Allergen` |

**Версионный кэш блюд** — при любом изменении `Dish`/`Category`/`Tag`/`Allergen` сигнал увеличивает счётчик `menu_dishes_cache_version` в Redis. Все старые ключи перестают использоваться и истекают по TTL самостоятельно. Разные наборы query-параметров (`?category_id=`, `?tag_ids=`, `?search=`) кэшируются отдельно.

Сигналы подключены в `apps/menu/signals.py`, зарегистрированы через `MenuConfig.ready()`.

## Важные нюансы

- Блюда с `is_active=False` не возвращаются API — скрывать блюдо нужно через Django-админку, не удалять.
- Сортировка блюд: сначала по `category__order`, затем по `id` внутри категории.
- `video` — необязательное поле. Клиент должен проверять `video_url` на `null` перед воспроизведением (воспроизводить нужно `video_url`, а не `video`).
- `price` приходит строкой (`"4500.00"`), а не числом — стандартное поведение `DecimalField` в DRF.
- Категории и теги управляются только через Django-админку, публичного эндпоинта на создание нет.
- `video_status` индексируется в БД. Составной индекс `(is_active, video_status)` ускоряет запросы видеоленты.
- FFmpeg устанавливается внутри Docker-образа (`apt-get install ffmpeg`). В production на S3 задаче нужно сначала скачать оригинальный файл во временный каталог перед транскодированием.
- При загрузке нового `video` в уже существующее блюдо задача ставится в очередь повторно только если `video_status` не `processing` и не `ready`. Чтобы принудительно переобработать — сбросить статус в `pending` через Django Shell или Django Admin.

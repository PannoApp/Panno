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
      "video_url": "http://localhost:8000/media/dishes/videos/processed/dish_3_processed.mp4",
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
      "image": "/media/dishes/images/steak.jpg",
      "video": "/media/dishes/videos/steak.mp4",
      "video_url": "http://localhost:8000/media/dishes/videos/processed/dish_1_processed.mp4",
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
| `image` | image | Фото блюда (обязательное) |
| `video` | file | Оригинальное видео, загружаемое администратором (необязательное) |
| `video_processed` | file | Транскодированное видео H.264/720×1280 (заполняется Celery, не редактируется вручную) |
| `video_status` | enum | Статус обработки: `pending` / `processing` / `ready` / `failed` |
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

## Файлы модуля

```
apps/menu/
├── models.py       # Category, Tag, Allergen, Dish (+ VideoStatus enum)
├── serializers.py  # CategorySerializer, TagSerializer, AllergenSerializer, DishSerializer
├── views.py        # CategoryListView, DishListView, VideoFeedView
├── filters.py      # DishFilter (category_id, tag_ids, search)
├── tasks.py        # process_dish_video — Celery-задача FFmpeg транскодирования
├── signals.py      # trigger_video_processing, кэш-инвалидация
└── urls.py         # /categories/, /dishes/, /feed/
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

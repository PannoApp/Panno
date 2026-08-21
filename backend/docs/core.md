# Модуль: core

Отвечает за хранение и отдачу публичной информации о ресторане.

## Особенность: Singleton-модель

`RestaurantInfo` — это **синглтон**: в базе данных всегда существует ровно одна запись с `pk=1`. Удалить её нельзя. Редактируется только через Django-админку.

Это сделано намеренно: информация о ресторане статична и меняется редко.

## Эндпоинт

### GET /api/v1/core/info/

Возвращает публичную информацию о ресторане.

**Авторизация:** не нужна

**Ответ 200:**
```json
{
  "address": "г. Алматы, ул. Панфилова, 98",
  "working_hours": "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00",
  "working_hours_note": "Закрыто 1 января",
  "is_open_now": true,
  "tour_link": "https://tour.example.com/panno",
  "twogis_link": "https://2gis.kz/almaty/firm/123456789",
  "feedback_url": "https://forms.example.com/panno-feedback",
  "phone": "+7 727 123-45-67",
  "whatsapp": "+77001234567",
  "telegram": "@panno_restaurant",
  "instagram": "panno.restaurant",
  "concept_description": "Modern Nomad — кухня кочевников. Вкусы Центральной Азии в современной интерпретации.",
  "hero_slides": [
    {
      "id": 1,
      "image": "https://cdn.example.com/media/core/hero/f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6.jpg",
      "order": 0
    }
  ],
  "visit_rules": [
    {"title": "Дресс-код", "body": "Деловой casual..."},
    {"title": "Дети", "body": "Приветствуются до 21:00..."}
  ],
  "privacy_policy": "Настоящая политика...",
  "terms_of_service": "Пользуясь приложением..."
}
```

Поля `tour_link`, `twogis_link`, `feedback_url`, `phone`, `whatsapp`, `telegram`, `instagram`, `concept_description` могут быть пустой строкой, если не заполнены в админке. `hero_slides` возвращает пустой список `[]`, если изображения не загружены.

## Модель RestaurantInfo

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Всегда равен `1` |
| `address` | string | Адрес ресторана (до 500 символов) |
| `working_hours` | string | Основное расписание (до 500 символов), например `Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00` |
| `working_hours_note` | string | Временное изменение режима (пустая строка если нет активного уведомления). Пример: `Закрыто 1 января`. Flutter показывает поверх основного расписания. |
| `is_open_now` | bool | Вычисляемое свойство — открыт ли ресторан прямо сейчас (парсит `working_hours`, см. подробности ниже) |
| `tour_link` | URL | Ссылка на 3D-тур (необязательная) |
| `twogis_link` | URL | Ссылка на 2GIS (необязательная) |
| `feedback_url` | URL | Ссылка для обратной связи — форма, `mailto:`, WhatsApp-чат и т.п. (необязательная) |
| `phone` | string | Телефон для связи |
| `whatsapp` | string | Контакт в WhatsApp |
| `telegram` | string | Контакт в Telegram |
| `instagram` | string | Ссылка/никнейм Instagram |
| `concept_description` | text | Краткое описание концепции ресторана (главный экран приложения) |
| `hero_slides` | array | Список изображений-слайдов для главного экрана. Каждый слайд: `{id, image, order}`. Поле `image` — **абсолютный URL** к JPEG, автоматически обрезанному до 16:9. Имя файла — UUID hex (32 символа). При замене или удалении слайда старый файл удаляется из хранилища автоматически (django-cleanup). |
| `visit_rules` | array | Правила посещения — список `{title, body}`, отсортированных по `order`. Управляется через inline в Django Admin. |
| `privacy_policy` | URL | Ссылка на политику обработки персональных данных |
| `terms_of_service` | URL | Ссылка на пользовательское соглашение |

### is_open_now / is_open_at

`is_open_now` — обёртка над методом модели `is_open_at(weekday, at_time)`, который и делает всю работу. Логика заметно сложнее простого «нашли один диапазон времени»:

- Строка `working_hours` разбивается на **сегменты** по запятым, точкам с запятой или переносам строк (например, `Пн-Пт: 12:00-23:00, Сб-Вс: 12:00-00:00` — два сегмента).
- В каждом сегменте ищется диапазон времени `HH:MM-HH:MM` и, отдельно, дни недели: диапазоны вида `пн-пт` (в том числе «через воскресенье», например `сб-вт`) и/или отдельные дни (`пн`, `ср`).
- Если сегмент вообще не содержит упоминания дней недели, считается, что этот интервал действует **на все 7 дней**.
- Каждый сегмент корректно обрабатывает переход через полночь (`close_t <= open_t`, например `20:00-02:00`).
- Итоговый результат — **OR по всем сегментам**: если хотя бы один сегмент покрывает переданные `(weekday, at_time)`, ресторан считается открытым.
- Возвращает `None`, если ни в одном сегменте не удалось распознать диапазон времени (строка не по формату).

`is_open_now` вызывает `is_open_at` с текущими локальными weekday/time (`django.utils.timezone.localtime`). Тот же метод `is_open_at` переиспользуется в `apps/bookings/serializers.py` для валидации даты/времени бронирования — гость не может забронировать столик на момент, когда ресторан закрыт, согласно тому же `working_hours`.

---

## Эндпоинт

### GET /api/v1/core/app-version/

Возвращает минимальную и последнюю версию приложения для конкретной платформы.

**Авторизация:** не нужна

**Query-параметры:** `platform` — `ios` или `android` (обязательный)

**Ответ 200:**
```json
{
  "platform": "ios",
  "min_version": "1.0.0",
  "latest_version": "1.3.0",
  "store_url": "https://apps.apple.com/app/panno/id123",
  "updated_at": "2026-05-12T10:00:00+06:00"
}
```

**Ответ 404** — если `platform` не передан или не найден.

## Модель AppVersion

| Поле | Тип | Описание |
|---|---|---|
| `platform` | string | Платформа: `ios` или `android` (уникальное) |
| `min_version` | string | Минимальная поддерживаемая версия — ниже этой версии приложение должно принудительно обновиться |
| `latest_version` | string | Последняя доступная версия — ниже этой версии показывается баннер "доступно обновление" |
| `store_url` | URL | Ссылка на страницу приложения в App Store / Google Play |
| `updated_at` | datetime | Дата последнего обновления записи (auto) |

---

## Эндпоинт

### GET /api/v1/core/interior/

Возвращает все фотографии интерьера, сгруппированные по зонам.

**Авторизация:** не нужна

**Ответ 200:**
```json
[
  {
    "id": 1,
    "zone": "cave",
    "zone_display": "Пещера",
    "image": "https://piligrim.kz/media/interior/a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6.jpg",
    "caption": "Пещера, 40 мест",
    "order": 0
  },
  {
    "id": 2,
    "zone": "bar",
    "zone_display": "Бар",
    "image": "https://piligrim.kz/media/interior/b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6.jpg",
    "caption": "",
    "order": 0
  }
]
```

Результаты отсортированы по `zone ASC`, затем `order ASC`. Поле `image` — **абсолютный URL**. Фотографии интерьера не обрезаются автоматически — отображаются fullscreen с `BoxFit.contain` во Flutter. Управление исключительно через Django-админку. При замене фото или удалении объекта старый файл удаляется из хранилища автоматически (django-cleanup).

**Зоны (`zone`):** `bar`, `cave`, `event_space`, `veranda`.

---

## Django Admin — контроль ролей

| Секция | admin | content_manager | hall_manager |
|---|---|---|---|
| `RestaurantInfo` (контакты, часы, контент главной, юридика) | ✅ view/change | ✅ view/change | ❌ |
| `AppVersion` (версии приложения) | ✅ full | ❌ | ❌ |
| `InteriorPhoto` (фото интерьера) | ✅ full | ✅ full | ❌ |

**Важно:** при назначении роли (`role != ''`) в `UserAdmin` поле `is_staff` автоматически устанавливается в `True` — иначе сотрудник не может войти в Django Admin. При снятии роли `is_staff` сбрасывается в `False` (кроме суперпользователей).

## Эндпоинт

### GET /api/v1/core/health/

Проверяет работоспособность PostgreSQL и Redis. **Для DevOps и мониторинга, Flutter не использует.**

**Авторизация:** не нужна

**Ответ 200** — все сервисы работают:
```json
{
  "status": "ok",
  "db": "ok",
  "redis": "ok"
}
```

**Ответ 503** — хотя бы один сервис недоступен:
```json
{
  "status": "degraded",
  "db": "ok",
  "redis": "error"
}
```

---

## Начальное заполнение данных

### Management command: `seed_initial_data`

Создаёт начальные данные после первого `migrate` на новом окружении.

```bash
# Создать если ещё нет (безопасно запускать повторно)
python manage.py seed_initial_data

# Перезаписать существующие данные данными-заглушками
python manage.py seed_initial_data --force
```

**Что создаёт:**
- `RestaurantInfo` — адрес, часы работы, телефон (заглушки, заменить в Admin)
- `AppVersion(ios)` — `min_version=1.0.0`, `latest_version=1.0.0`
- `AppVersion(android)` — `min_version=1.0.0`, `latest_version=1.0.0`

**Поведение без `--force`:** если запись уже существует и заполнена — пропускается. Идемпотентен.

**После выполнения:** обязательно зайди в Django Admin и замени заглушки реальными данными.

---

## Файлы модуля

```
apps/core/
├── models.py       # RestaurantInfo (Singleton), InteriorPhoto, AppVersion
├── serializers.py  # RestaurantInfoSerializer, AppVersionSerializer, InteriorPhotoSerializer
├── views.py        # RestaurantInfoView, AppVersionView, InteriorPhotoListView
├── admin.py        # RestaurantInfoAdmin, InteriorPhotoAdmin, AppVersionAdmin (роли)
├── urls.py         # Маршруты /api/v1/core/
├── health.py       # HealthCheckView (GET /api/v1/core/health/)
└── management/commands/seed_initial_data.py  # Начальное заполнение БД
```

## Кэширование

Все публичные эндпоинты модуля кэшируют результаты в Redis, чтобы не делать SELECT при каждом запросе.

| Эндпоинт | Ключ кэша | TTL | Инвалидация |
|---|---|---|---|
| `GET /api/v1/core/info/` | `restaurant_info` | 3600 сек | `post_save` / `post_delete` на `RestaurantInfo` |
| `GET /api/v1/core/interior/` | `interior_photos` | 3600 сек | `post_save` / `post_delete` на `InteriorPhoto` |

Сигналы инвалидации подключены в `apps/core/signals.py`, зарегистрированы через `CoreConfig.ready()`.

**Пробел в инвалидации:** `hero_slides` и `visit_rules` в ответе `/info/` берутся из отдельных моделей (`HeroSlide`, `VisitRule`), редактируемых как inline в `RestaurantInfoAdmin`. Сигналы инвалидации зарегистрированы только для `sender=RestaurantInfo` и `sender=InteriorPhoto` — сохранение/удаление `HeroSlide` или `VisitRule` **не** триггерит сброс ключа `restaurant_info`. После правки слайда или правила через inline кэш может отдавать устаревшие данные вплоть до истечения полного TTL (3600 сек).

## Важные нюансы

- Метод `RestaurantInfo.load()` возвращает единственную запись или создаёт её с пустыми полями, если она ещё не существует. Используй его вместо `get(pk=1)`.
- Метод `save()` принудительно устанавливает `pk=1` — случайно создать вторую запись нельзя.
- Метод `delete()` переопределён и ничего не делает — запись нельзя удалить.
- Если нужно добавить новые поля (например, телефон, Instagram) — добавляй в модель и создавай миграцию. Поле сразу появится в API, если добавить его в `fields` сериализатора.

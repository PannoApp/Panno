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
  "working_hours": "Пн–Вс: 12:00–00:00",
  "is_open_now": true,
  "tour_link": "https://tour.example.com/panno",
  "twogis_link": "https://2gis.kz/almaty/firm/123456789",
  "phone": "+7 727 123-45-67",
  "whatsapp": "+77001234567",
  "telegram": "@panno_restaurant",
  "instagram": "panno.restaurant",
  "concept_description": "Modern Nomad — кухня кочевников. Вкусы Центральной Азии в современной интерпретации.",
  "hero_image": "https://cdn.example.com/media/core/hero.jpg",
  "hero_video_url": "https://cdn.example.com/media/core/hero.mp4",
  "visit_rules": "Дресс-код: smart casual. Дети до 12 лет...",
  "privacy_policy": "Настоящая политика...",
  "terms_of_service": "Пользуясь приложением..."
}
```

Поля `tour_link`, `twogis_link`, `phone`, `whatsapp`, `telegram`, `instagram`, `hero_video_url`, `concept_description` могут быть пустой строкой, если не заполнены в админке. `hero_image` возвращает `null`, если изображение не загружено.

## Модель RestaurantInfo

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Всегда равен `1` |
| `address` | string | Адрес ресторана (до 500 символов) |
| `working_hours` | string | Часы работы в произвольном формате, например `Пн–Вс: 12:00–00:00` |
| `is_open_now` | bool | Вычисляемое свойство — открыт ли ресторан прямо сейчас (парсит `working_hours`) |
| `tour_link` | URL | Ссылка на 3D-тур (необязательная) |
| `twogis_link` | URL | Ссылка на 2GIS (необязательная) |
| `phone` | string | Телефон для связи |
| `whatsapp` | string | Контакт в WhatsApp |
| `telegram` | string | Контакт в Telegram |
| `instagram` | string | Ссылка/никнейм Instagram |
| `concept_description` | text | Краткое описание концепции ресторана (главный экран приложения) |
| `hero_image` | image | Заглавное изображение главного экрана (файл, URL или `null`) |
| `hero_video_url` | URL | Ссылка на заглавное видео (YouTube, CDN и т.п.; пустая строка если не задана) |
| `visit_rules` | text | Правила посещения ресторана |
| `privacy_policy` | text | Политика обработки персональных данных |
| `terms_of_service` | text | Пользовательское соглашение |

### is_open_now

Свойство парсит строку `working_hours` регулярным выражением и ищет диапазон вида `HH:MM–HH:MM`. Корректно обрабатывает переход через полночь (например, `20:00–02:00`). Возвращает `None`, если строка не распознана.

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

## Файлы модуля

```
apps/core/
├── models.py       # RestaurantInfo (Singleton), AppVersion
├── serializers.py  # RestaurantInfoSerializer, AppVersionSerializer
├── views.py        # RestaurantInfoView, AppVersionView
└── urls.py         # Маршруты /api/v1/core/
```

## Важные нюансы

- Метод `RestaurantInfo.load()` возвращает единственную запись или создаёт её с пустыми полями, если она ещё не существует. Используй его вместо `get(pk=1)`.
- Метод `save()` принудительно устанавливает `pk=1` — случайно создать вторую запись нельзя.
- Метод `delete()` переопределён и ничего не делает — запись нельзя удалить.
- Если нужно добавить новые поля (например, телефон, Instagram) — добавляй в модель и создавай миграцию. Поле сразу появится в API, если добавить его в `fields` сериализатора.

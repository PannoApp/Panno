# Документация Backend — Panno Restaurant API

## Стек

| Технология | Версия | Роль |
|---|---|---|
| Django | 5.x | Фреймворк |
| Django REST Framework | 3.15 | REST API |
| PostgreSQL | — | Основная БД |
| Redis | — | Кэш OTP-кодов, брокер Celery |
| Celery | 5.x | Фоновые задачи (push-уведомления) |
| Firebase Admin SDK | 6.x | Отправка FCM push-уведомлений |
| drf-spectacular | 0.29 | Генерация OpenAPI 3.0 документации |
| Simple JWT | 5.x | JWT авторизация |

## Архитектура

```
backend/
├── config/              # Настройки Django (base, dev, prod) и роутинг
├── apps/
│   ├── users/           # Авторизация (SMS OTP) и профиль пользователя
│   ├── menu/            # Категории и блюда меню
│   ├── events/          # Мероприятия, новости, запись на события
│   ├── bookings/        # Бронирование столов
│   ├── core/            # Публичная информация о ресторане
│   └── notifications/   # FCM push-уведомления и устройства
├── utils/               # Общие утилиты (пагинация)
└── docs/                # Эта документация
```

## Модули

- [users.md](users.md) — Авторизация через SMS OTP, JWT, профиль
- [menu.md](menu.md) — Категории, блюда, теги, аллергены
- [events.md](events.md) — Мероприятия, новости, запись на события
- [bookings.md](bookings.md) — Бронирование столов
- [core.md](core.md) — Информация о ресторане
- [notifications.md](notifications.md) — Push-уведомления (FCM)
- [testing.md](testing.md) — Unit-тесты: запуск локально и в Docker

## Быстрый старт

```bash
# Установить зависимости
python -m pip install -r requirements.txt

# Запустить в Docker
docker-compose up --build

# Применить миграции
python manage.py migrate

# Создать суперпользователя для админки
python manage.py createsuperuser

# Запустить тесты (локально, без PostgreSQL и Redis)
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps

# Запустить тесты в Docker
docker-compose run --rm --no-deps backend \
  python manage.py test apps --settings=config.settings.test

# Сгенерировать openapi.yaml
python manage.py spectacular --file openapi.yaml
```

## Swagger UI

Доступен **только в режиме разработки** (`DEBUG=True`). В production эти маршруты отсутствуют.

| URL | Описание |
|---|---|
| `/api/docs/` | Swagger UI — интерактивная документация |
| `/api/redoc/` | ReDoc — читаемая документация |
| `/api/schema/` | Сырая OpenAPI 3.0 схема (JSON/YAML) |

## Добавление нового эндпоинта

1. Создать view в `apps/<модуль>/views.py`
2. Добавить `@extend_schema(...)` с тегом, summary, описанием и схемами ответов
3. Прописать URL в `apps/<модуль>/urls.py`
4. Обновить `openapi.yaml`: `python manage.py spectacular --file openapi.yaml`

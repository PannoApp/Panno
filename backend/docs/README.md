# Документация Backend — Panno Restaurant API

## Стек

| Технология | Версия | Роль |
|---|---|---|
| Django | 5.2 | Фреймворк |
| Django REST Framework | 3.15 | REST API |
| PostgreSQL | — | Основная БД |
| Redis | — | Кэш OTP-кодов, брокер Celery |
| Celery | 5.6 | Фоновые задачи (push-уведомления) |
| Firebase Admin SDK | 6.5 | Отправка FCM push-уведомлений |
| drf-spectacular | 0.29 | Генерация OpenAPI 3.0 документации |
| Simple JWT | 5.3 | JWT авторизация |

## Архитектура

```
backend/
├── config/              # Настройки Django (base/dev/prod/test), Celery, роутинг
├── apps/
│   ├── users/           # Авторизация (SMS OTP) и профиль пользователя
│   ├── menu/            # Категории и блюда меню
│   ├── events/          # Мероприятия, новости, запись на события
│   ├── bookings/        # Бронирование столов
│   ├── core/            # Публичная информация о ресторане
│   ├── notifications/   # FCM push-уведомления и устройства
│   └── remarked/        # HTTP-клиенты к CRM Remarked (без моделей/вьюх/urls, см. remarked.md)
├── utils/               # Общие утилиты: пагинация, кэш, идемпотентность, обработка изображений,
│                        # логирующий middleware, кастомный exception handler, права доступа
└── docs/                # Эта документация
```

## Модули

- [users.md](users.md) — Авторизация через SMS OTP, JWT, профиль
- [menu.md](menu.md) — Категории, блюда, теги, аллергены
- [events.md](events.md) — Мероприятия, новости, запись на события
- [bookings.md](bookings.md) — Бронирование столов
- [core.md](core.md) — Информация о ресторане
- [notifications.md](notifications.md) — Push-уведомления (FCM)
- [remarked.md](remarked.md) — Клиенты к CRM Remarked (`apps/remarked/`), брони/меню/стоп-лист
- [remarked-push-integration.md](remarked-push-integration.md) — Формат push-уведомлений для прямой отправки через Remarked/FCM
- [logging.md](logging.md) — Логирование HTTP-запросов и обработка исключений DRF
- [admin.md](admin.md) — Роли пользователей и матрица разрешений в Django Admin
- [for_admins.md](for_admins.md) — Руководство для администратора контента (`/admin/`)
- [DEPLOY.md](DEPLOY.md) — Деплой на staging-сервер через Docker
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

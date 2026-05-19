# Piligrim — Пилигрим

Мобильное приложение и REST API для ресторана с казахской эстетикой. Духовно-гастрономическое путешествие: кухня свободы и традиций.

---

## Стек

| Слой | Технология |
|---|---|
| Мобильный клиент | Flutter 3.x (Dart) |
| Backend API | Django 5 + Django REST Framework |
| База данных | PostgreSQL 16 (через PgBouncer) |
| Кэш / брокер | Redis 7 |
| Фоновые задачи | Celery 5 + Celery Beat |
| Push-уведомления | Firebase Cloud Messaging (FCM) |
| Мониторинг задач | Flower |
| API-документация | drf-spectacular (OpenAPI 3.0) |
| Авторизация | SMS OTP + JWT (SimpleJWT) |

---

## Структура репозитория

```
/                        ← Flutter-приложение (pubspec.yaml, lib/, ios/, android/)
/backend/                ← Django-бэкенд
  ├── config/            ← Настройки (base/dev/prod/test), URL-роутинг, Celery
  ├── apps/
  │   ├── users/         ← SMS OTP авторизация, профиль, JWT
  │   ├── menu/          ← Категории, блюда, теги, аллергены, видео-лента
  │   ├── events/        ← Мероприятия, новости, запись на события
  │   ├── bookings/      ← Бронирование столов, зоны, статусы, напоминания
  │   ├── core/          ← Публичная информация о ресторане (синглтон)
  │   └── notifications/ ← FCM push, устройства, кампании
  ├── utils/             ← Пагинация, логирование middleware
  └── docs/              ← Документация по каждому модулю
/brand/                  ← Дизайн-спецификация (piligrim_design_spec.md)
```

---

## Быстрый старт

### Backend (Docker — рекомендуется)

```bash
cd backend

# Создать .env из примера и заполнить переменные
cp .env.example .env

# Запустить все сервисы
docker compose up --build

# Применить миграции
docker compose exec backend python manage.py migrate

# Создать суперпользователя для Django Admin
docker compose exec backend python manage.py createsuperuser
```

Сервисы после запуска:

| Сервис | URL |
|---|---|
| Django API | http://localhost:8000 |
| Swagger UI | http://localhost:8000/api/docs/ |
| ReDoc | http://localhost:8000/api/redoc/ |
| Django Admin | http://localhost:8000/admin/ |
| Flower (Celery) | http://localhost:5555 |

### Flutter

```bash
# Из корня репозитория
flutter pub get
flutter run
```

---

## Авторизация

Пароли не используются. Вход в два шага:

```
POST /api/v1/users/auth/request-sms/   ← отправить номер телефона
        ↓ SMS с 4-значным OTP (в DEBUG — код в консоль)
POST /api/v1/users/auth/verify-sms/    ← номер + OTP → access + refresh JWT
```

Новый пользователь создаётся автоматически при первом входе. Выход (`POST /api/v1/users/auth/logout/`) добавляет refresh-токен в чёрный список.

---

## API: основные эндпоинты

| Метод | URL | Описание | Auth |
|---|---|---|---|
| POST | `/api/v1/users/auth/request-sms/` | Запросить SMS с OTP | — |
| POST | `/api/v1/users/auth/verify-sms/` | Подтвердить OTP, получить JWT | — |
| POST | `/api/v1/users/auth/token/refresh/` | Обновить access-токен | — |
| POST | `/api/v1/users/auth/logout/` | Выйти (блокировка refresh) | JWT |
| GET | `/api/v1/users/profile/` | Профиль пользователя | JWT |
| PATCH | `/api/v1/users/profile/` | Обновить профиль | JWT |
| GET | `/api/v1/core/info/` | Информация о ресторане | — |
| GET | `/api/v1/menu/categories/` | Список категорий меню | — |
| GET | `/api/v1/menu/dishes/` | Блюда с фильтрами | — |
| GET | `/api/v1/menu/feed/` | Видео-лента блюд | — |
| GET | `/api/v1/events/upcoming/` | Предстоящие мероприятия | — |
| GET | `/api/v1/events/archived/` | Прошедшие мероприятия | — |
| GET | `/api/v1/events/news/` | Новости ресторана | — |
| POST | `/api/v1/events/reservations/create/` | Записаться на мероприятие | JWT |
| POST | `/api/v1/bookings/create/` | Забронировать стол | JWT |
| GET | `/api/v1/bookings/my/` | Мои бронирования | JWT |
| POST | `/api/v1/notifications/devices/register/` | Зарегистрировать FCM-токен | JWT |

Полная документация — [Swagger UI](http://localhost:8000/api/docs/) или `backend/API_FOR_FLUTTER.md`.

---

## Модули backend

| Модуль | Документация |
|---|---|
| Авторизация и профиль | [docs/users.md](backend/docs/users.md) |
| Меню и блюда | [docs/menu.md](backend/docs/menu.md) |
| Мероприятия и новости | [docs/events.md](backend/docs/events.md) |
| Бронирование столов | [docs/bookings.md](backend/docs/bookings.md) |
| Информация о ресторане | [docs/core.md](backend/docs/core.md) |
| Push-уведомления | [docs/notifications.md](backend/docs/notifications.md) |
| Логирование | [docs/logging.md](backend/docs/logging.md) |
| Тесты | [docs/testing.md](backend/docs/testing.md) |
| Django Admin | [docs/admin.md](backend/docs/admin.md) |
| Технический долг | [docs/technical_debt.md](backend/docs/technical_debt.md) |

---

## Тесты

```bash
# Все тесты в Docker
docker compose exec backend python manage.py test

# Конкретное приложение
docker compose exec backend python manage.py test apps.bookings

# Конкретный тест-кейс
docker compose exec backend python manage.py test apps.bookings.tests.TableBookingModelTest

# Локально (без Docker, без PostgreSQL/Redis)
cd backend
DJANGO_SETTINGS_MODULE=config.settings.test python manage.py test apps
```

---

## Flutter: архитектура

- **Навигация:** `IndexedStack` для вкладок, именованные маршруты для деталей.
- **State management:** `InheritedNotifier` (`AmbientPresetScope`) для темы окружения; `SharedPreferences` для персистентности.
- **HTTP:** `dio` с JWT-интерцептором и auto-refresh; токены хранятся в `flutter_secure_storage`.
- **Push:** `firebase_messaging` — FCM-токен передаётся на бэкенд через `/api/v1/notifications/devices/register/`.
- **Видео:** `video_player` для ленты блюд.
- **Типографика:** MuseoSans 300/700 (только эти веса загружены из assets).
- **Ориентация:** только портретная (заблокировано в `main.dart`).
- **Ambient-тема:** три пресета (calm / ember / mystic) с гироскопными эффектами через `sensors_plus`.

Подробнее: [Plan_For_Flutter.md](Plan_For_Flutter.md) и [brand/piligrim_design_spec.md](brand/piligrim_design_spec.md).

---

## Переменные окружения

Создайте `backend/.env` на основе `backend/.env.example`:

```
SECRET_KEY=
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

POSTGRES_DB=piligrim
POSTGRES_USER=piligrim
POSTGRES_PASSWORD=
POSTGRES_HOST=db
POSTGRES_PORT=5432

REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Опционально
USE_S3=False
FLOWER_USER=admin
FLOWER_PASSWORD=
REDIS_PASSWORD=
```

---

## Настройки Django

| Модуль | Назначение |
|---|---|
| `config.settings.base` | Общие настройки (Docker, production) |
| `config.settings.dev` | Разработка: TTL access-токена 1 день, email в консоль |
| `config.settings.prod` | Production: TTL 30 минут, валидация обязательных env-переменных |
| `config.settings.test` | Тесты: SQLite in-memory, без Redis |

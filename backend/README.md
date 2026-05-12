# Panno — Backend API

REST API для мобильного приложения ресторана. Django 5 + DRF.

---

## Что умеет приложение

### Авторизация (`/api/users/`)

Беспарольная авторизация по номеру телефона через SMS-OTP.

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| POST | `/api/users/auth/request-sms/` | Отправить 4-значный OTP на номер | Нет |
| POST | `/api/users/auth/verify-sms/` | Проверить OTP, получить JWT-токены | Нет |
| GET | `/api/users/profile/` | Получить профиль текущего пользователя | JWT |
| PATCH | `/api/users/profile/` | Обновить имя/фамилию | JWT |

- OTP хранится в Redis, TTL 3 минуты
- Троттлинг: 3 запроса/мин на отправку, 5 запросов/мин на проверку
- При первом входе пользователь создаётся автоматически

---

### Меню (`/api/menu/`)

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| GET | `/api/menu/categories/` | Список категорий (сортировка по `order`) | Нет |
| GET | `/api/menu/dishes/` | Список блюд с пагинацией и фильтрацией | Нет |

Блюда поддерживают:
- Фильтрацию по категории
- Теги и аллергены (M2M)
- Фото и видео (для ленты в стиле видеофида)
- Пагинация: 5 блюд на страницу (`?page_size=N`, max 20)

---

### Афиша и Новости (`/api/events/`)

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| GET | `/api/events/upcoming/` | Предстоящие мероприятия | Нет |
| GET | `/api/events/archived/` | Прошедшие мероприятия | Нет |
| GET | `/api/events/news/` | Новости заведения | Нет |
| POST | `/api/events/reservations/create/` | Записаться на мероприятие | JWT |
| GET | `/api/events/reservations/my/` | Мои записи на мероприятия | JWT |

- Один пользователь не может записаться на одно мероприятие дважды
- Пагинация: 20 записей на страницу

---

### Бронирование столов (`/api/bookings/`)

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| GET | `/api/bookings/` | Список моих броней | JWT |
| POST | `/api/bookings/` | Создать бронь | JWT |

Поля брони: имя гостя, дата, время, количество гостей (1–50), комментарий.

Статусы: `pending` → `confirmed` / `canceled` / `completed`

При смене статуса бронирования пользователю автоматически уходит push-уведомление (через Celery + FCM).

---

### Информация о ресторане (`/api/core/`)

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| GET | `/api/core/info/` | Адрес, часы работы, ссылки на 2GIS и 3D-тур | Нет |

Singleton-модель — в базе всегда ровно одна запись, редактируется через Django Admin.

---

### Push-уведомления (`/api/notifications/`)

| Метод | URL | Описание | Auth |
|-------|-----|----------|------|
| POST | `/api/notifications/device/register/` | Зарегистрировать FCM-токен устройства | JWT |

- Один пользователь может иметь несколько устройств
- Невалидные токены удаляются автоматически после неудачной отправки
- Push отправляется асинхронно через Celery

---

## Стек

| Слой | Технология |
|------|-----------|
| Фреймворк | Django 5 + Django REST Framework 3.15 |
| Auth | SimpleJWT (Bearer-токены) |
| БД | PostgreSQL 16 + PgBouncer |
| Кэш / Брокер | Redis 7 |
| Очереди | Celery 5.3 |
| Push | Firebase Admin SDK (FCM) |
| Медиафайлы | Локально (dev) / S3-совместимое хранилище (MinIO/AWS) |
| Деплой | Docker Compose |

---

## Переменные окружения

Создай `.env` на основе `.env.example`:

```
SECRET_KEY=
DEBUG=True
ALLOWED_HOSTS=

POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_HOST=pgbouncer
POSTGRES_PORT=6432

REDIS_URL=redis://redis:6379/1
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

USE_S3=False

FIREBASE_CREDENTIALS_PATH=/app/firebase-credentials.json
```

---

## Запуск

```bash
docker compose up --build
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
```

Админка: `http://localhost:8000/admin/`

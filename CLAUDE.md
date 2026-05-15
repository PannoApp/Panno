# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository Layout

This is a **Flutter mobile app + Django REST API** monorepo:

```
/                    ← Flutter app root (pubspec.yaml, lib/, ios/, android/)
/backend/            ← Django backend (all Python work happens here)
/brand/              ← Design specs / TZ documents
```

All backend commands must be run from `/Users/arhat/Desktop/Panno/backend/`.

---

## Backend: Commands

**Run locally (Docker — preferred):**
```bash
cd backend
docker compose up --build          # Start all services (postgres, redis, django, celery worker)
docker compose up -d               # Detached
docker compose logs -f backend     # Tail Django logs
```

**Django management (inside container or venv):**
```bash
# Inside container
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py makemigrations

# Via venv (requires local .env)
cd backend
source .venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.dev python manage.py runserver
```

**Celery worker + beat:**
```bash
docker compose logs -f worker   # Tail worker logs
docker compose logs -f beat     # Tail beat logs
docker compose logs -f flower   # Flower UI at http://localhost:5555
```

**Run tests:**
```bash
docker compose exec backend python manage.py test apps.bookings
docker compose exec backend python manage.py test          # All tests
# Single test class:
docker compose exec backend python manage.py test apps.bookings.tests.TableBookingModelTest
```

**Settings modules:**
- `config.settings.base` — shared (used in Docker / production)
- `config.settings.dev` — local development overrides
- `config.settings.test` — test overrides

**API docs:** `http://localhost:8000/api/docs/` (Swagger UI), `http://localhost:8000/api/redoc/`

---

## Backend: Architecture

### Django Apps (`backend/apps/`)

| App | Responsibility |
|---|---|
| `users` | Custom `User` model (phone-based auth), SMS OTP via Redis, JWT via simplejwt |
| `menu` | `Category`, `Tag`, `Allergen`, `Dish` models; filtering via `django-filters` |
| `events` | `Event`, `News`, `EventReservation` models |
| `bookings` | `TableBooking` + lifecycle signals that fire FCM push on status change |
| `notifications` | `UserDevice` (FCM tokens), Celery task `send_push_notification` |
| `core` | `RestaurantInfo` singleton (`.load()` class method), served via `GET /api/core/info/` |

### Key Patterns

**Auth flow:** `POST /api/users/auth/request-sms/` → Redis stores OTP (3-min TTL) → `POST /api/users/auth/verify-sms/` → returns JWT pair. Public endpoints use `AllowAny`; protected ones use `IsAuthenticated` + `JWTAuthentication`.

**Push notifications:** `send_push_notification(user_id, title, body, data)` is a Celery `@shared_task` in `notifications/tasks.py`. It looks up all `UserDevice.fcm_token` for the user and calls `firebase_admin.messaging.send_multicast`. Invalid tokens are auto-deleted.

**Booking signals:** `bookings/signals.py` uses `post_save` to detect status transitions (`_original_status` saved in `__init__`) and queue push via Celery.

**Pagination:** `utils/pagination.py` — `StandardPagination` (page_size=20, max=100), `VideoFeedPagination` (page_size=5).

**Logging:** All requests logged as JSON by `utils/logging_middleware.RequestLoggingMiddleware` (first in MIDDLEWARE). Logs rotate at 10 MB, 5 backups, written to `backend/logs/app.log`.

**Migrations:** Each app has its own `migrations/` directory. Always run `makemigrations <app>` when changing models.

### Config & Infrastructure

- **Settings:** split into `base.py` / `dev.py` / `prod.py` / `test.py` under `config/settings/`
- **Celery:** `config/celery.py` — app name `piligrim`, autodiscovers `tasks.py` in all apps.
- **Storage:** `USE_S3=True` env switches from `FileSystemStorage` to `django-storages` S3 backend
- **Docker Compose services:** `db` (PostgreSQL 16), `pgbouncer` (connection pooler), `redis` (Redis 7), `backend` (Django), `worker` (Celery worker), `beat` (Celery Beat — periodic tasks), `flower` (Celery monitoring UI, port 5555)

### Documentation

`backend/docs/` contains per-module API and model documentation. **Always update the relevant `docs/*.md` file when changing models, serializers, or endpoints.** Files:
- `docs/users.md`, `docs/bookings.md`, `docs/events.md`, `docs/menu.md`
- `docs/core.md`, `docs/notifications.md`, `docs/logging.md`, `docs/testing.md`

---

## Flutter App

The Flutter project lives at the repo root (`lib/`, `pubspec.yaml`). Backend integration details are in `backend/API_FOR_FLUTTER.md`.

---

## Environment Variables

Required in `backend/.env` (see `.env.example` if present):
```
SECRET_KEY, DEBUG, ALLOWED_HOSTS
POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_HOST, POSTGRES_PORT
REDIS_URL, CELERY_BROKER_URL, CELERY_RESULT_BACKEND
USE_S3 (optional), AWS_* (if USE_S3=True)
```

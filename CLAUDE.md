# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository Layout

This is a **Flutter mobile app + Django REST API** monorepo named **Piligrim** (Пилигрим):

```
/                    ← Flutter app root (pubspec.yaml, lib/, ios/, android/)
/backend/            ← Django backend (all Python work happens here)
/brand/              ← Design specs / TZ documents
/Plan_For_Flutter.md ← Flutter implementation plan
```

All backend commands: `cd backend` from the repo root.

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
docker compose exec backend python manage.py makemigrations <app>

# Via venv (requires local .env)
cd backend
source .venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.dev python manage.py runserver
```

**Celery:**
```bash
docker compose logs -f worker   # Tail worker logs
docker compose logs -f beat     # Tail beat logs
docker compose logs -f flower   # Flower UI at http://localhost:5555
```

**Run tests:**
```bash
docker compose exec backend python manage.py test apps.bookings
docker compose exec backend python manage.py test          # All tests
docker compose exec backend python manage.py test apps.bookings.tests.TableBookingModelTest
```

**Settings modules:**
- `config.settings.base` — shared (used in Docker / production)
- `config.settings.dev` — local development overrides (1-day JWT access TTL, console email)
- `config.settings.prod` — production (30-min JWT TTL, validates required env vars at startup)
- `config.settings.test` — test overrides

**API docs:** `http://localhost:8000/api/docs/` (Swagger UI), `http://localhost:8000/api/redoc/`

---

## Backend: Architecture

### Django Apps (`backend/apps/`)

| App | Responsibility |
|---|---|
| `users` | Custom `User` model (phone-based auth), SMS OTP via Redis, JWT via simplejwt, notification preferences per user |
| `menu` | `Category`, `Tag`, `Allergen`, `Dish` models; video field for feed; filtering via `django-filters` |
| `events` | `Event` (open/closed format, nullable price), `News`, `EventReservation` models |
| `bookings` | `TableBooking` with zones (main/terrace/private) and statuses (pending/confirmed/canceled/completed); signals fire FCM push on status change |
| `notifications` | `UserDevice` (FCM tokens), `PushCampaign` model; Celery task `send_push_notification` |
| `core` | `RestaurantInfo` singleton (`.load()`), `AppVersion`, `InteriorPhoto`; `GET /api/v1/core/info/` |

### Key Patterns

**API versioning:** All routes are prefixed `/api/v1/`. Auth URLs are `/api/v1/users/auth/`.

**Auth flow:** `POST /api/v1/users/auth/request-sms/` → Redis stores OTP (3-min TTL) → `POST /api/v1/users/auth/verify-sms/` → returns JWT pair + creates user if new. `POST /api/v1/users/auth/logout/` blacklists refresh token. Public endpoints use `AllowAny`; protected ones use `IsAuthenticated` + `JWTAuthentication`.

**Push notifications:** `send_push_notification(user_id, title, body, data, category)` is a Celery `@shared_task` in `notifications/tasks.py`. It checks the user's per-category notification preferences (`notify_events`, `notify_promotions`, `notify_closed_events`), enforces a 3-marketing-pushes/week cap and a 9am–9pm delivery window, then calls `firebase_admin.messaging.send_multicast`. Invalid tokens are auto-deleted.

**Booking signals:** `bookings/signals.py` uses `post_save` to detect status transitions (`_original_status` saved in `__init__`) and queues the appropriate push via Celery. Celery Beat also runs `send_booking_reminders` every 15 minutes to push reminders for confirmed bookings 1–2 hours out.

**Caching (Redis):** `GET /api/v1/core/info/` and menu categories/dishes cached 1 hour (dishes with filters 5 min); events/news 60 seconds–5 minutes.

**Throttling:** Anonymous 60/min, authenticated 300/min; `sms_request` scope 3/min, `sms_verify` scope 5/min.

**PgBouncer:** Transaction-mode pooling — `DISABLE_SERVER_SIDE_CURSORS = True` is required in Django settings for compatibility.

**Pagination:** `utils/pagination.py` — `StandardPagination` (page_size=20, max=100), `VideoFeedPagination` (page_size=5).

**Logging:** All requests logged as JSON by `utils/logging_middleware.RequestLoggingMiddleware` (first in MIDDLEWARE). Logs rotate at 10 MB, 5 backups, written to `backend/logs/app.log`.

**Migrations:** Always run `makemigrations <app>` (not bare `makemigrations`) when changing models.

### Config & Infrastructure

- **Settings:** `base.py` / `dev.py` / `prod.py` / `test.py` under `config/settings/`
- **Celery:** `config/celery.py` — app name `piligrim`, autodiscovers `tasks.py` in all apps
- **Storage:** `USE_S3=True` env switches to `django-storages` S3 backend (MinIO/AWS/Selectel compatible)
- **Docker Compose services:** `db` (PostgreSQL 16), `pgbouncer` (port 6432), `redis` (Redis 7), `backend` (Django, port 8000), `worker` (Celery, concurrency=4), `beat` (Celery Beat), `flower` (port 5555)

### Documentation

`backend/docs/` contains per-module API and model documentation. **Always update the relevant `docs/*.md` file when changing models, serializers, or endpoints.** Files:
- `docs/users.md`, `docs/bookings.md`, `docs/events.md`, `docs/menu.md`
- `docs/core.md`, `docs/notifications.md`, `docs/logging.md`, `docs/testing.md`, `docs/admin.md`, `docs/technical_debt.md`

Flutter-facing API reference: `backend/API_FOR_FLUTTER.md` (includes Dio interceptor examples, auth flow, caching strategy, all endpoints).

---

## Flutter App

The Flutter project lives at the repo root. Culturally-themed restaurant client (Kazakh aesthetic).

**Cursor rules (UI, nav, layout):** `.cursor/rules/piligrim-*.mdc` — prefer these over guessing conventions.

**Flutter docs (per feature):** `docs/flutter/*.md` — auth, menu, booking, events, api_client, etc.

**Implementation plan / audit:** `Plan_For_Flutter.md` (architecture decisions, open tasks).

### App Structure (`lib/`)

- `main.dart` — `MultiProvider`, `SplashScreen` → `RootShell` (`IndexedStack` + `PiligrimNavBar`)
- `screens/` — splash, home, menu, interior, events, profile, booking, phone_entry, event_detail, …
- `widgets/` — brand UI (`piligrim_*`, `home_*`, `ember_*`), e.g. `piligrim_tap.dart`, `home_cinematic_ambient.dart`, `dish_video_card.dart`
- `providers/` — `AuthProvider`, `CoreInfoProvider`, `MenuProvider`, `EventsProvider`, `BookingProvider` (`ChangeNotifier`)
- `data/repositories/` + `data/services/` — Dio API layer (`DioClient`, JWT interceptor, `TokenStorage`)
- `core/` — `theme.dart`, `ambient_preset_scope.dart` (global ambient `AnimationController`), `home_data.dart` / `menu_data.dart` / `profile_data.dart` (static UI registries, not API mocks)

### State & navigation

- **State:** `provider` + `ChangeNotifier` only (no Riverpod / Bloc / GetX).
- **Tabs:** fixed order in `RootShell` — Home · Menu · Interior · Events · Profile.
- **Details / booking / auth:** `Navigator.push` + `MaterialPageRoute` (no `go_router`, no named routes).
- **Auth gate:** `guardAuth(context)` in `lib/core/auth_guard.dart`.

### Key Flutter Facts

- **API wired:** `dio`, repositories, providers; reference `backend/API_FOR_FLUTTER.md`.
- Events may fall back to mocks in `data/events_news_data.dart` on network failure; menu uses live API.
- Font: MuseoSans 300/700 only. Design: `brand/piligrim_design_spec.md`.
- Portrait-only in `main.dart`. Home uses `sensors_plus` parallax + cinematic ambient layers.
- Large screens (`profile_screen`, `menu_screen`, `events_screen`) are intentional monoliths — do not split unless asked.

### Flutter Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

---

## Environment Variables

Required in `backend/.env`:
```
SECRET_KEY, DEBUG, ALLOWED_HOSTS
POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_HOST, POSTGRES_PORT
REDIS_URL, CELERY_BROKER_URL, CELERY_RESULT_BACKEND
USE_S3 (optional), AWS_* (if USE_S3=True)
FLOWER_USER, FLOWER_PASSWORD (optional)
REDIS_PASSWORD (optional)
```

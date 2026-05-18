# Афиша и мероприятия (Block 6)

## API

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/events/upcoming/` | Ближайшие события (пагинация DRF) |
| GET | `/events/archived/` | Архив прошедших |
| GET | `/events/news/` | Новости ресторана |
| POST | `/events/reservations/create/` | Запись на событие (JWT) |

Тело записи: `{ "event": <id>, "guests_count": <int> }`.  
Заголовок: `Idempotency-Key` (UUID) — защита от дублей.

Поля события: `date_time`, `image`, `format` (`open` / `closed`), `price`, `is_past`, опционально `has_photo_report`.

## Слой данных

- `EventsRepository` — Dio-запросы, парсинг через `PaginatedResponse`
- `EventsProvider` — состояние экрана афиши, `reserveEvent`, fallback на моки при ошибке сети
- `ApiEvent` — модель для UI; хелперы в `api_event_display.dart`
- `EventCoverImage` — CDN + локальный fallback из `PiligrimInteriorAssets`

## UI

- `EventsScreen` — `Consumer<EventsProvider>`, списки upcoming / archived / news
- `EventDetailScreen` — деталь + «Записаться» через `guardAuth` и `showEventSignupSheet`
- `event_signup_sheet.dart` — только число гостей; имя/телефон из профиля
- `InteriorScreen` — сетка из `CoreInfoProvider.interiorSlides` или локальные PNG

## Запуск

Данные подгружаются в `main.dart`:

```dart
ChangeNotifierProvider(create: (_) => EventsProvider()..load()),
```

`CoreInfoProvider` должен быть загружен для вкладки «Интерьер» (Block 4).

## Тесты

```bash
flutter test test/data/repositories/events_repository_test.dart
flutter test test/providers/events_provider_test.dart
flutter test test/widgets/event_signup_sheet_test.dart
```

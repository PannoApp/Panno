# Афиша и мероприятия (Block 6)

## API

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/events/upcoming/` | Ближайшие события (пагинация DRF) |
| GET | `/events/archived/` | Архив прошедших |
| GET | `/events/news/` | Новости ресторана |
| POST | `/events/reservations/create/` | Запись на событие (JWT) |
| GET | `/events/<id>/photo-report/` | Фотоотчёт прошедшего события (плоский массив, без авторизации) |

Тело записи: `{ "event": <id>, "guests_count": <int> }`.  
Заголовок: `Idempotency-Key` (UUID) — защита от дублей. Генерируется один раз в `EventsProvider` при первой попытке записи и сохраняется для защиты от дубликатов при сетевых повторах (retries) одной и той же формы.

Поля события: `date_time`, `image`, `format` (`open` / `closed`), `price`, `is_past`, `has_photo_report`.  
Поля фото: `id`, `image` (URL), `order`.

## Слой данных

- `EventsRepository` — Dio-запросы, парсинг через `PaginatedResponse`
  - `fetchPhotoReport(eventId)` → `List<ApiEventPhoto>` — GET `/events/<id>/photo-report/`
- `EventsProvider` — состояние экрана афиши, `reserveEvent`, fallback на моки при ошибке сети
  - `loadPhotoReport(eventId)` — вызывается в `initState` `EventDetailScreen` если `event.isPast`
  - `photoReport` — `List<ApiEventPhoto>` (unmodifiable), `isLoadingPhotoReport` — флаг загрузки
  - При ошибке сети устанавливает пустой список (не бросает)
- `ApiEvent` — модель для UI; хелперы в `api_event_display.dart`; поле `hasPhotoReport` заполняется сервером
- `ApiEventPhoto` — `lib/data/models/api_event_photo.dart`; поля: `id`, `imageUrl`, `order`
- `EventCoverImage` — CDN + локальный fallback из `PiligrimInteriorAssets`

## UI

- `EventsScreen` — `Consumer<EventsProvider>`, списки upcoming / archived / news
- `EventDetailScreen` — **StatefulWidget**; в `initState` запускает `loadPhotoReport` для прошедших событий;
  под описанием добавляет секцию «Фотоотчёт» через `Consumer<EventsProvider>` (скелетон во время загрузки,
  галерея при наличии фото, `SizedBox.shrink()` при пустом списке)
- `EventPhotoReportGallery` — `lib/widgets/event_photo_report_gallery.dart`;
  `PageView` с `viewportFraction: 0.92`, `CachedNetworkImage`, скруглённые углы 12px;
  при пустом `photos` возвращает `SizedBox.shrink()`
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
flutter test test/data/repositories/events_photo_report_repository_test.dart
flutter test test/providers/events_provider_test.dart
flutter test test/widgets/event_signup_sheet_test.dart
flutter test test/widgets/event_photo_report_gallery_test.dart
```

Тесты `loadPhotoReport` в `events_provider_test.dart` проверяют:
- успешная загрузка → список из 2 фото, `isLoadingPhotoReport = false`
- ошибка сети → пустой список, нет исключения
- флаг `isLoadingPhotoReport` поднят во время загрузки и сброшен после

Тесты репозитория в `events_photo_report_repository_test.dart` проверяют:
- парсинг JSON-массива в `List<ApiEventPhoto>`
- пустой массив → пустой список
- правильный URL эндпоинта (`/events/7/photo-report/`)
- `DioException` при HTTP 500

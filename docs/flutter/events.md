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
- `EventsProvider` — состояние экрана афиши
  - `loadUpcoming()` / `loadArchived()` / `loadNews()`: при ошибке сети устанавливают **пустой список** (`upcoming`/`archived`/`news` = `const []`) и заполняют соответствующее поле `*Error` текстом ошибки — никакого fallback на моковые данные нет
  - `reserveEvent(eventId, guestsCount)`: при ошибке заполняет `reserveError` и **пробрасывает исключение дальше** (`rethrow`) — вызывающий код (bottom sheet записи) сам обрабатывает ошибку, тихого fallback нет
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

---

## Admin: редактирование мероприятия

**Файл:** `lib/screens/event_edit_screen.dart`

Форма создания/редактирования мероприятия для персонала. `EventEditScreen(event: null)` — создание; `EventEditScreen(event: someEvent)` — редактирование.

### Поля формы

- Обложка мероприятия — выбор из галереи + кадрирование 16:9, live-превью карточки
- Название *, Описание, Дата и время * (последовательно `showDatePicker` → `showTimePicker`; при создании нельзя выбрать прошедшую дату), Формат * (`open` / `closed`, выпадающий список), Цена (₸) (пусто = свободный вход), Максимум мест (`0` — без ограничений), переключатель «Отображать на афише» (`is_active`)

### Сохранение и удаление

- Кнопка «ОПУБЛИКОВАТЬ» / «СОХРАНИТЬ ИЗМЕНЕНИЯ» вызывает `EventsProvider.createEvent(fields, image:)` или `EventsProvider.updateEvent(id, fields, image:)`, которые бьют в `POST` / `PATCH /events/admin/events/{id}/` и при успехе перезагружают все списки (`load()`)
- Значок удаления в AppBar (только при редактировании) открывает диалог подтверждения → `EventsProvider.deleteEvent(id)` (`DELETE /events/admin/events/{id}/`); в отличие от `deleteArchivedEvent` (используется в архиве), этот метод тоже вызывает `load()`, т.к. удаляемое мероприятие может быть как предстоящим, так и архивным
- Ошибки сохранения/удаления показываются через `PiligrimToast` с текстом из `EventsProvider.saveEventError`

### Точка входа

FAB на `lib/screens/events_screen.dart`, видимый только при `AuthProvider.isAdmin`; там же — кнопка «Новость» (см. ниже) и кнопка редактирования на карточках предстоящих/архивных мероприятий.

### Тесты

```bash
flutter test test/widgets/event_edit_screen_test.dart
```

---

## Admin: редактирование новости

**Файл:** `lib/screens/news_edit_screen.dart`

Форма создания/редактирования новости ресторана, по структуре аналогична `EventEditScreen`. `NewsEditScreen(news: null)` — создание; `NewsEditScreen(news: somePost)` — редактирование.

### Поля формы

- Обложка новости — выбор из галереи + кадрирование 16:9 (опционально)
- Заголовок *, Текст новости * (многострочное поле)

### Сохранение и удаление

- Кнопка сохранения вызывает `EventsProvider.createNews(fields, image:)` или `EventsProvider.updateNews(id, fields, image:)` → `POST` / `PATCH /events/admin/news/{id}/`, при успехе перезагружает `loadNews()`
- Удаление (значок в AppBar, только при редактировании, с диалогом подтверждения) → `EventsProvider.deleteNews(id)` → `DELETE /events/admin/news/{id}/`
- Ошибки — `PiligrimToast` с текстом из `EventsProvider.saveNewsError`

### Точка входа

Кнопка «Новость» рядом с FAB мероприятий на `events_screen.dart` (видна при `isAdmin`), а также кнопка редактирования на карточке новости.

### Тесты

```bash
flutter test test/widgets/news_edit_screen_test.dart
```

---

## Admin: фотоотчёт мероприятия

**Файл:** `lib/screens/event_photo_report_screen.dart`

Экран управления фотоотчётом **прошедшего** мероприятия, доступен только персоналу. `EventPhotoReportScreen(event: pastEvent)`.

- Сетка 2 колонки (`GridView.builder`, `childAspectRatio: 1.0`) с фотографиями из `EventsProvider.photoReport` (загружается в `initState` через `loadPhotoReport(eventId)`)
- Добавление фото — кнопка в AppBar и FAB (оба вызывают один и тот же `_addPhoto`): выбор из галереи, кадрирование **без фиксированного соотношения сторон** (в отличие от 16:9 у блюд/событий/новостей), затем `EventsProvider.addPhotoToReport(eventId, file)` → `POST /events/admin/events/{id}/photos/`; при успехе также обновляет `hasPhotoReport` в архиве (`loadArchived()`)
- Удаление фото — тап по крестику на плитке открывает диалог подтверждения → `EventsProvider.deletePhotoFromReport(eventId, photoId)` → `DELETE /events/admin/events/{id}/photos/{photoId}/`; если после удаления фотоотчёт становится пустым, список архива тоже перезагружается
- Состояния: загрузка (`PiligrimLoader`), ошибка с кнопкой «Повторить», пустой список («Нет фотографий»)

### Точка входа

Кнопка на карточке архивного мероприятия в `events_screen.dart`, видимая только при `isAdmin`.

### Как получить эндпоинты

`POST /events/admin/events/{id}/photos/` и `DELETE /events/admin/events/{id}/photos/{photoId}/` — административные эндпоинты фотоотчёта, отдельные от публичного `GET /events/<id>/photo-report/` из таблицы API выше; см. `backend/docs/events.md`.

---

## Мои мероприятия (история записей пользователя)

**Файл:** `lib/screens/event_reservation_history_screen.dart`

Обычный (не staff) экран авторизованного пользователя — список его записей на мероприятия. Открывается из `profile_screen.dart` («Мои мероприятия»).

- В `initState` вызывает `EventsProvider.loadMyReservations()` → `GET /events/reservations/my/`, результат — `myReservations: List<ApiEventReservation>`
- Карточка записи показывает название события, бейдж «ПРЕДСТОИТ»/«ЗАВЕРШЕНО» (по `event.isPast`), дату, время и число гостей (со склонением: «1 герой» / «2–4 героя» / «5+ героев»)
- Состояния: загрузка, ошибка с кнопкой «Повторить» (`retryMyReservations()`), пустой список

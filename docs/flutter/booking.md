# Блок 7: Система бронирования столиков

Документация охватывает Flutter-сторону функциональности бронирования: модели, репозиторий, провайдер, экраны.

---

## Схема состояний бронирования

Бронирование проходит через четыре статуса. Переходы управляются **бекендом** (Django сигналы); Flutter только отображает текущий статус.

```
                   ┌──────────┐
   POST /bookings/ │          │
 ─────────────────▶│ pending  │
                   │ Ожидает  │
                   └────┬─────┘
                        │ менеджер подтверждает
                        ▼
                   ┌──────────────┐
                   │  confirmed   │
                   │ Подтверждено │
                   └──────┬───────┘
                          │                    │
              визит состоялся          менеджер отменяет
                          │                    │
                          ▼                    ▼
                   ┌───────────┐      ┌──────────────┐
                   │ completed │      │   canceled   │
                   │ Завершено │      │   Отменено   │
                   └───────────┘      └──────────────┘
```

Терминальные статусы (`completed`, `canceled`) — конечные, обратный переход невозможен.

---

## BookingProvider API

Файл: [lib/providers/booking_provider.dart](../../lib/providers/booking_provider.dart)

`BookingProvider extends ChangeNotifier` — единственный источник истины для состояния формы и истории бронирований. Регистрируется в дереве виджетов через `MultiProvider` в `main.dart`.

### Поля состояния формы

| Поле | Тип | Значение по умолчанию | Описание |
|---|---|---|---|
| `selectedZone` | `String?` | `'Главный зал'` | Выбранная зона зала |
| `guests` | `int` | `2` | Количество гостей (1–50) |
| `visitDate` | `DateTime?` | `null` | Дата визита |
| `visitTime` | `DateTime?` | `null` | Время визита |

### Поля состояния отправки

| Поле | Тип | Описание |
|---|---|---|
| `isSubmitting` | `bool` | `true` во время HTTP-запроса |
| `isSuccess` | `bool` | `true` после успешного создания |
| `error` | `String?` | Текст ошибки или `null` |

### Поля истории

| Поле | Тип | Описание |
|---|---|---|
| `history` | `List<ApiBooking>` | Список бронирований пользователя |
| `isLoadingHistory` | `bool` | `true` во время загрузки истории |
| `historyError` | `String?` | Ошибка загрузки истории или `null` |

### Методы

#### `setZone(String? zone)`
Обновляет выбранную зону зала и вызывает `notifyListeners()`.

#### `setGuests(int count)`
Устанавливает количество гостей с ограничением `clamp(1, 50)`.

#### `setVisitDate(DateTime date)` / `setVisitTime(DateTime time)`
Обновляют дату и время визита соответственно.

#### `Future<void> submitBooking(BookingRequest req)`
Отправляет заявку на бронирование.

- Защита от двойной отправки: при `isSubmitting == true` возвращает сразу.
- Последовательность: устанавливает `isSubmitting = true` → вызывает `_repository.createBooking(req)` → при успехе устанавливает `isSuccess = true` и сбрасывает форму через `_resetForm()` → при ошибке записывает в `error`.
- После завершения `isSubmitting` всегда сбрасывается в `false` (блок `finally`).

#### `Future<void> loadHistory({int page = 1})`
Загружает историю бронирований текущего пользователя.

- Защита от параллельных запросов: при `isLoadingHistory == true` возвращает сразу.
- Результат записывается в `history`; при ошибке — в `historyError`.

#### `resetSubmitState()`
Сбрасывает `isSuccess` и `error` в исходное состояние. Вызывается при повторном открытии экрана бронирования, чтобы не показывать устаревший результат.

#### `_resetForm()` (приватный)
Сбрасывает поля формы к значениям по умолчанию после успешной отправки.

```
selectedZone = 'Главный зал'
guests = 2
visitDate = null
visitTime = null
```

### Доступные зоны

```dart
static const zones = ['Главный зал', 'Терраса', 'Приват'];
```

Соответствие API-значениям (маппинг в `BookingScreen`):

| Flutter-название | API-значение (backend enum) |
|---|---|
| Главный зал | `main` |
| Терраса | `terrace` |
| Приват | `private` |

---

## Idempotency-Key

Файл: [lib/data/repositories/booking_repository.dart](../../lib/data/repositories/booking_repository.dart)

### Зачем нужен

Пользователь может нажать «Отправить» в момент нестабильного соединения: запрос уйдёт на сервер, но ответ не вернётся. При повторной попытке без Idempotency-Key бекенд создаст дублирующую заявку. Заголовок позволяет бекенду распознать повтор и вернуть результат первого запроса без создания дубля.

### Где генерируется

Ключ генерируется непосредственно перед каждым HTTP-запросом в `BookingRepository.createBooking()`:

```dart
static const _uuid = Uuid();   // пакет uuid

await _dio.post<Map<String, dynamic>>(
  '/bookings/',
  data: req.toJson(),
  options: Options(
    headers: {'Idempotency-Key': _uuid.v4()},
  ),
);
```

Каждый вызов `createBooking` получает новый UUID v4. Это означает, что **защита от дублей работает только в рамках одной попытки** (retry на уровне сети). Если пользователь нажимает кнопку повторно — генерируется новый ключ, и это считается новым запросом.

---

## Prefill телефона из профиля

Файл: [lib/screens/booking_screen.dart](../../lib/screens/booking_screen.dart) — метод `initState`, строки 52–60.

При открытии `BookingScreen` форма автоматически заполняется данными авторизованного пользователя:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final auth = context.read<AuthProvider>();
  if (!auth.isLoggedIn) return;
  _nameCtrl.text = auth.user.name;
  final phone = auth.user.phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (phone.isNotEmpty) _phoneCtrl.text = phone;
});
```

**Детали реализации:**

- Заполнение происходит в `addPostFrameCallback`, а не в `initState` напрямую, чтобы гарантировать доступность `BuildContext` с провайдерами.
- Телефон очищается от всех символов кроме цифр и `+` (`RegExp(r'[^\d+]')`), чтобы убрать пробелы и дефисы, которые могут храниться в профиле.
- Если пользователь не авторизован — форма остаётся пустой; кнопка отправки запустит `guardAuth`, который перенаправит на экран входа.
- Prefill можно редактировать — поля остаются обычными `TextEditingController`.

---

## Статусы и цветовое кодирование в BookingHistoryScreen

Файл: [lib/screens/booking_history_screen.dart](../../lib/screens/booking_history_screen.dart) — класс `_StatusBadge`, строки 281–331.

Каждая карточка бронирования отображает badge со статусом. Цвет берётся из палитры `PiligrimColors`.

| Статус API | Русское название | Цвет | Константа / HEX |
|---|---|---|---|
| `pending` | ОЖИДАЕТ | Золотистый | `PiligrimColors.steppe` |
| `confirmed` | ПОДТВЕРЖДЕНО | Синий (вода) | `PiligrimColors.water` |
| `completed` | ЗАВЕРШЕНО | Зелёный | `Color(0xFF5A9A6A)` |
| `canceled` | ОТМЕНЕНО | Приглушённый серый | `PiligrimColors.sky` с alpha 0.30 |

Badge рендерится как контейнер с:
- фоном цвета с opacity 0.12 (полупрозрачный),
- рамкой того же цвета с opacity 0.40,
- текстом в `UPPERCASE` с `letterSpacing: 1.2` и размером шрифта 9.5.

Неизвестный статус обрабатывается ветвью `default` — отображается как «Отменено» (серый).

---

## Модели данных

### BookingRequest

Файл: [lib/data/models/booking_request.dart](../../lib/data/models/booking_request.dart)

Исходящая модель для `POST /api/v1/bookings/`. Все поля передаются в `snake_case` через `toJson()`.

| Поле Dart | JSON-ключ | Обязательное | Описание |
|---|---|---|---|
| `guestName` | `guest_name` | да | Имя гостя |
| `phone` | `phone` | да | Телефон |
| `date` | `date` | да | Дата в формате `YYYY-MM-DD` |
| `time` | `time` | да | Время в формате `HH:mm` |
| `guestsCount` | `guests_count` | да | Количество гостей |
| `zone` | `zone` | нет | API-значение зоны (`main`/`terrace`/`private`) |
| `comment` | `comment` | нет | Комментарий гостя |

### ApiBooking

Файл: [lib/data/models/api_booking.dart](../../lib/data/models/api_booking.dart)

Входящая модель для ответов `GET /api/v1/bookings/`. Поддерживает оба варианта ключей (`snake_case` и `camelCase`) для совместимости.

Дополнительно к полям `BookingRequest` содержит:

| Поле | Тип | Описание |
|---|---|---|
| `id` | `int` | Идентификатор записи на бекенде |
| `status` | `String` | Текущий статус (`pending`/`confirmed`/`completed`/`canceled`) |

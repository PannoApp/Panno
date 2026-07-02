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

Файлы: [lib/providers/booking_provider.dart](../../lib/providers/booking_provider.dart) и [lib/data/repositories/booking_repository.dart](../../lib/data/repositories/booking_repository.dart)

### Зачем нужен

Пользователь может нажать «Отправить» в момент нестабильного соединения: запрос уйдёт на сервер, но ответ не вернётся. При повторной попытке без Idempotency-Key бекенд создаст дублирующую заявку. Заголовок позволяет бекенду распознать повтор и вернуть результат первого запроса без создания дубля.

### Где генерируется

Ключ генерируется один раз при первой попытке отправки формы в `BookingProvider.submitBooking()` и сохраняется в состоянии провайдера:

```dart
_idempotencyKey ??= const Uuid().v4();

try {
  await _repository.createBooking(
    req,
    idempotencyKey: _idempotencyKey!,
  );
  // ...
}
```

Это означает, что **защита от дублей работает при всех сетевых повторах (retries)** для одной и той же заполненной формы. Если пользователь нажимает кнопку повторно (например, после ошибки таймаута) — используется тот же сохранённый ключ, и бекенд возвращает статус исходной операции. Ключ сбрасывается (`_idempotencyKey = null`) только после успешной отправки заявки или при принудительном сбросе формы.

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

---

## Экран успешного бронирования (BookingSuccessScreen)

Файл: [lib/screens/booking_success_screen.dart](../../lib/screens/booking_success_screen.dart)

После успешной отправки заявки (`booking.isSuccess == true`) `BookingScreen._submit()` выполняет `Navigator.push` на `BookingSuccessScreen`. Форма очищается **до** навигации — повторная отправка исключена.

### Конструктор

```dart
BookingSuccessScreen({
  required String date,         // «ДД.ММ.ГГГГ» — форматированная дата
  required String time,         // «ЧЧ:ММ» — форматированное время
  required int heroesCount,     // количество гостей
  String? zone,                 // читаемое название зала («Главный зал» / «Терраса» / «Приват»)
  required bool depositRequired,// признак из CoreInfo.bookingDepositRequired
})
```

### Что рендерит экран

| Элемент | Описание |
|---|---|
| Тотем `bird_totem` | Spring-анимация: scale (600 мс, `elasticOut`) + rotate (600 мс, `easeOut`) |
| Заголовок «ПУТЬ ЗАБРОНИРОВАН» | fadeIn + slideY, задержка 200 мс |
| Подзаголовок | «Ваша заявка успешно отправлена проводникам», задержка 300 мс |
| Карточка деталей | Дата/время, кол-во героев (склонение), зона (если выбрана) |
| Список «Сценарий после отправки» | 3 шага (+ 4-й при `depositRequired == true`) |
| Кнопки навигации | «МОИ БРОНИРОВАНИЯ» и «НА ГЛАВНУЮ» |

### Склонение heroes count

Метод `_formatHeroesCount(int count)` возвращает:
- `«1 герой»` — если `count % 10 == 1 && count % 100 != 11`
- `«2–4 героя»` — если `count % 10` ∈ [2, 4] и не попадает в 11–14
- `«N героев»` — иначе

### Навигация с экрана

| Кнопка | Действие |
|---|---|
| «МОИ БРОНИРОВАНИЯ» | `Navigator.pushReplacement` → `BookingHistoryScreen` (форма убирается из стека) |
| «НА ГЛАВНУЮ» | `Navigator.popUntil((r) => r.isFirst)` → корневой маршрут (`RootShell`) |

### Условный шаг при депозите

Когда `depositRequired == true`, в список «Сценарий после отправки» добавляется 4-й пункт:
> «Для выбранного стола нужен депозит — менеджер направит вас на звонок.»

---

## Баннер депозита и звонок менеджеру

Файл: [lib/screens/booking_screen.dart](../../lib/screens/booking_screen.dart), строки 401–468.

### Условие показа

Баннер рендерится **внутри формы** бронирования, между полем «Комментарий» и кнопкой отправки:

```dart
if (depositRequired) ...[
  // блок баннера
]
```

Значение `depositRequired` берётся из `context.watch<CoreInfoProvider>().coreInfo?.bookingDepositRequired ?? false`.

### Содержимое баннера

1. **Иконка** `Icons.info_outline_rounded` + **текст** из `CoreInfoProvider.coreInfo?.bookingDepositNote` (фолбэк: `'Для выбранного стола может потребоваться депозит. Уточните у менеджера.'`).
2. **Кнопка «ПОЗВОНИТЬ МЕНЕДЖЕРУ»** — вызывает `launchUrl(Uri.parse('tel:$phone'))`, где `phone = context.read<CoreInfoProvider>().coreInfo?.phone ?? ''`. Кнопка не показывается если `phone` пустой (вызов `launchUrl` не выполняется).

### Источник данных на бекенде

Поля `booking_deposit_required` и `booking_deposit_note` хранятся в модели `RestaurantInfo` (`backend/apps/core/models.py`) и возвращаются через `GET /api/v1/core/info/`. Оплата депозита через приложение не предусмотрена — только переадресация на звонок.

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

> **С бэкенда (без изменений в контрактах для Flutter):** каждая бронь теперь
> также дублируется в CRM Remarked, которой пользуется зал ресторана, и раз в
> 10 минут бэкенд подтягивает оттуда актуальный статус — то есть `confirmed`/
> `canceled`/`completed` может прийти не только из Django-админки/Telegram, но
> и из-за того, что сотрудник поменял статус прямо в Remarked. Для Flutter это
> прозрачно: `status` в ответе `GET /api/v1/bookings/` — как и раньше, просто
> строка, никаких новых полей и изменений формата не появилось. Подробности —
> `backend/docs/bookings.md`, раздел «Синхронизация с Remarked».

---

## BookingProvider API

Файл: [lib/providers/booking_provider.dart](../../lib/providers/booking_provider.dart)

`BookingProvider extends ChangeNotifier` — единственный источник истины для состояния формы и истории бронирований. Регистрируется в дереве виджетов через `MultiProvider` в `main.dart`.

### Поля состояния формы

| Поле | Тип | Значение по умолчанию | Описание |
|---|---|---|---|
| `selectedZone` | `BookingZone?` | `null` | Выбранный зал (реальный, из Remarked — см. «Залы» ниже) |
| `guests` | `int` | `2` | Количество гостей (1–50) |
| `visitDate` | `DateTime?` | `null` | Дата визита |
| `visitTime` | `DateTime?` | `null` | Время визита |

### Поля залов

| Поле | Тип | Описание |
|---|---|---|
| `zones` | `List<BookingZone>` | Реальные залы ресторана, см. `loadZones()` ниже |
| `isLoadingZones` | `bool` | `true` во время загрузки списка залов |
| `zonesError` | `String?` | Ошибка загрузки или `null` |

### Поля столов

| Поле | Тип | Описание |
|---|---|---|
| `selectedTable` | `BookingTable?` | Выбранный стол внутри выбранного зала, `null` = «Любой стол» |
| `tables` | `List<BookingTable>` | Свободные столы зала на точные дату/время/кол-во гостей, см. `loadTables()` ниже |
| `isLoadingTables` | `bool` | `true` во время загрузки списка столов |
| `tablesError` | `String?` | Ошибка загрузки или `null` |

### Поля доступности

| Поле | Тип | Описание |
|---|---|---|
| `availabilitySlots` | `List<AvailabilitySlot>` | Свободные слоты на выбранную дату/кол-во гостей/зал, см. `loadAvailability()` ниже |
| `isLoadingAvailability` | `bool` | `true` во время проверки доступности |
| `availabilityError` | `String?` | Ошибка проверки доступности или `null` |

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

#### `setZone(BookingZone? zone)`
Обновляет выбранный зал и сбрасывает всё, что зависело от предыдущего зала:
`selectedTable = null`, `tables = []`, `tablesError = null`. После
`notifyListeners()` перезапускает и `loadAvailability()` (занятость должна
пересчитаться для нового зала), и `loadTables()` (список столов грузится
заново для нового зала — см. «Столы» ниже).

#### `Future<void> loadZones()`
Загружает список реальных залов через `_repository.fetchZones()`. Не
перезапускает загрузку, если список уже не пуст или загрузка уже идёт
(`zones.isNotEmpty || isLoadingZones` → no-op). Ошибка не ломает форму —
`zonesError` заполняется, `zones` остаётся пустым, пикер зала в
`BookingScreen` просто не отображается (зал — необязательное поле).

#### `setTable(BookingTable? table)`
Обновляет выбранный стол и вызывает `notifyListeners()`. Никаких побочных
эффектов (в отличие от `setZone`) — выбор стола не влияет ни на список
залов, ни на доступность слотов.

#### `setGuests(int count)`
Устанавливает количество гостей с ограничением `clamp(1, 50)`.

#### `setVisitDate(DateTime date)` / `setVisitTime(DateTime time)`
Обновляют дату и время визита соответственно.

#### `Future<void> loadTables()`
Загружает свободные столы конкретного зала через
`_repository.fetchTables()` по точным дате/времени/кол-ву гостей и
`zoneId`. No-op (с очисткой `tables`/`selectedTable`, если они не пусты),
если `selectedZone == null`, `visitDate == null` или `visitTime == null` —
без зала «любой стол в любом зале» подбирается бэкендом автоматически, как
и раньше. Также no-op, если загрузка уже идёт (`isLoadingTables`). После
успешной загрузки, если ранее выбранного стола больше нет в списке
свежих `tables` (например, его уже забронировали), `selectedTable`
сбрасывается в `null`. При ошибке — `tablesError` заполняется, `tables` и
`selectedTable` сбрасываются.

#### `Future<void> loadAvailability()`
Проверяет доступность слотов через `_repository.fetchAvailability()` по
дате, кол-ву гостей и (опционально) `selectedZone?.id`. No-op, если
`visitDate == null` или загрузка уже идёт. Результат — в
`availabilitySlots`; при ошибке — в `availabilityError`, `availabilitySlots`
сбрасывается в `[]`.

#### `Future<void> submitBooking(BookingRequest req)`
Отправляет заявку на бронирование.

- Защита от двойной отправки: при `isSubmitting == true` возвращает сразу.
- Последовательность: устанавливает `isSubmitting = true` → вызывает `_repository.createBooking(req)` → при успехе устанавливает `isSuccess = true`, сбрасывает форму через `_resetForm()` и вызывает `loadHistory()` (счётчик «Бронирований» на экране профиля берёт данные из `history`, иначе он остался бы устаревшим до тех пор, пока гость сам не откроет экран истории) → при ошибке записывает в `error`.
- После завершения `isSubmitting` всегда сбрасывается в `false` (блок `finally`).

#### `Future<void> loadHistory({int page = 1})`
Загружает историю бронирований текущего пользователя.

- Защита от параллельных запросов: при `isLoadingHistory == true` возвращает сразу.
- Результат записывается в `history`; при ошибке — в `historyError`.

#### `resetSubmitState()`
Сбрасывает `isSuccess` и `error` в исходное состояние. Вызывается при повторном открытии экрана бронирования, чтобы не показывать устаревший результат.

#### `Future<void> retryHistory()`
Тонкая обёртка над `loadHistory()` — семантический алиас для повторной
попытки после ошибки (используется кнопкой «Повторить» на экране истории).

#### `_resetForm()` (приватный)
Сбрасывает поля формы к значениям по умолчанию после успешной отправки,
включая выбранный стол и состояние доступности.
`zones`/`isLoadingZones`/`zonesError` не сбрасываются — список залов не
зависит от конкретной заявки, перезагружать его на каждую новую бронь не нужно.

```
selectedZone = null
selectedTable = null
tables = []
tablesError = null
guests = 2
visitDate = null
visitTime = null
availabilitySlots = []
availabilityError = null
```

### Залы

Раньше здесь был захардкоженный список (`'Главный зал'`/`'Терраса'`/`'Приват'`
→ `main`/`terrace`/`private`), не совпадавший с реальными залами ресторана.
Теперь залы — реальные, приходят с бэкенда:

```dart
class BookingZone {
  final int id;      // GetSlots.rooms[].id в Remarked
  final String name; // например, "Зал 1"
}
```

Файл: [lib/data/models/booking_zone.dart](../../lib/data/models/booking_zone.dart).
Загружается через `BookingProvider.loadZones()` (см. выше) →
`BookingRepository.fetchZones()` → `GET /bookings/zones/`. `BookingScreen`
вызывает `loadZones()` в `initState` и рендерит кнопки зала только если
`booking.zones.isNotEmpty` — при недоступности Remarked (пустой список) блок
выбора зала просто не показывается, форма не блокируется. Повторный тап по
уже выбранному залу снимает выбор (`selectedZone = null`).

### Столы

Выбор конкретного стола — необязательный уточняющий шаг **поверх** выбора
зала, а не независимая от него подсистема: пикер столов появляется только
после того, как выбран зал и заполнены дата/время визита. Без выбранного
стола (`selectedTable == null`, «Любой стол») бэкенд подбирает стол
автоматически внутри выбранного зала — так же, как это происходило и до
появления этой возможности.

```dart
class BookingTable {
  final int id;         // GetSlots.rooms[].tables[].id в Remarked
  final String? name;   // например, "Стол 5", может отсутствовать
  final int? capacity;  // вместимость стола, может отсутствовать
}
```

Файл: [lib/data/models/booking_table.dart](../../lib/data/models/booking_table.dart).
Загружается через `BookingProvider.loadTables()` (см. выше) →
`BookingRepository.fetchTables()` → `GET /bookings/tables/` с параметрами
даты, времени, кол-ва гостей и `zoneId`. Список перезагружается заново при
любом изменении зала (`setZone()` вызывает `loadTables()`) и при изменении
даты/времени/гостей на экране бронирования. Если ранее выбранный стол
пропадает из свежего списка (уже занят), выбор молча сбрасывается
(`selectedTable = null`) — форма не блокируется. Смена зала всегда сбрасывает
выбранный стол (см. `setZone()` выше), так как список столов другого зала
не пересекается со старым выбором.

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

## Prefill телефона из профиля и инициализация формы

Файл: [lib/screens/booking_screen.dart](../../lib/screens/booking_screen.dart) — метод `initState`, строки 46–66.

При открытии `BookingScreen` весь `addPostFrameCallback` в `initState` делает
две вещи подряд: заполняет форму данными авторизованного пользователя и
синхронизирует черновик формы с `BookingProvider`, запуская первую загрузку
залов и проверку доступности.

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final auth = context.read<AuthProvider>();
  if (auth.isLoggedIn) {
    _nameCtrl.text = auth.user.name;
    final phone = auth.user.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isNotEmpty) _phoneCtrl.text = phone;
  }

  // Синхронизируем черновик формы с провайдером, грузим реальные залы
  // ресторана и запускаем первую проверку доступности слотов на
  // дефолтную дату/кол-во гостей.
  final booking = context.read<BookingProvider>();
  booking.setVisitDate(_visitDate);
  booking.setVisitTime(_visitTimeAsDateTime);
  booking.loadZones();
  booking.loadAvailability();
});
```

**Детали реализации:**

- Заполнение происходит в `addPostFrameCallback`, а не в `initState` напрямую, чтобы гарантировать доступность `BuildContext` с провайдерами.
- Телефон очищается от всех символов кроме цифр и `+` (`RegExp(r'[^\d+]')`), чтобы убрать пробелы и дефисы, которые могут храниться в профиле.
- Если пользователь не авторизован — блок prefill просто пропускается (`if (auth.isLoggedIn)`), форма остаётся пустой; кнопка отправки запустит `guardAuth`, который перенаправит на экран входа. Синхронизация с `BookingProvider` при этом всё равно выполняется — она не зависит от авторизации.
- Prefill можно редактировать — поля остаются обычными `TextEditingController`.
- Тот же callback сразу после prefill передаёт дефолтные дату/время экрана (`_visitDate`, `_visitTimeAsDateTime`) в провайдер через `setVisitDate`/`setVisitTime`, затем вызывает `loadZones()` (см. «Залы» выше) и `loadAvailability()` (см. «Поля доступности» выше) — так форма и провайдер оказываются синхронизированы уже к первому кадру экрана, без ожидания действий пользователя.

---

## Статусы и цветовое кодирование в BookingHistoryScreen

Файл: [lib/screens/booking_history_screen.dart](../../lib/screens/booking_history_screen.dart) — класс `_StatusBadge`, строки 282–336.

Каждая карточка бронирования отображает badge со статусом. Цвет берётся из палитры `PiligrimColors` (кроме `canceled` — см. ниже).

| Статус API | Русское название | Цвет | Константа / HEX |
|---|---|---|---|
| `pending` | ОЖИДАЕТ | Золотистый | `PiligrimColors.steppe` |
| `confirmed` | ПОДТВЕРЖДЕНО | Синий (вода) | `PiligrimColors.water` |
| `completed` | ЗАВЕРШЕНО | Зелёный | `PiligrimColors.success` (константа в `lib/core/theme.dart`, значение `Color(0xFF5A9A6A)`) |
| `canceled` | ОТМЕНЕНО | Приглушённый серый | `PiligrimColors.sky` с alpha 0.30 |

Badge — это не контейнер-«пилюля» с фоном и рамкой, а простой `Row` из двух
элементов:
- цветной кружок 5×5 (`Container` с `BoxDecoration(shape: BoxShape.circle)`, без фона/рамки вокруг всего badge),
- текст в `UPPERCASE` (`PiligrimTextStyles.caption`) с `letterSpacing: 1.2` и размером шрифта 9.5, окрашенный в тот же цвет, что и кружок.

Неизвестный статус обрабатывается той же веткой `case`, что и `canceled`
(`case 'canceled': default:`) — отображается как «Отменено» (серый).

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
| `zone` | `zone` | нет | Название реального зала (`BookingZone.name`, например «Зал 1») — свободный текст, не enum |
| `remarkedRoomId` | `remarked_room_id` | нет | `BookingZone.id` — нужен бэкенду, чтобы подобрать стол именно в этом зале |
| `remarkedTableId` | `remarked_table_id` | нет | `BookingTable.id` — если гость выбрал конкретный стол явно (а не «Любой стол»), бэкенд передаёт его в Remarked напрямую, без автоподбора |
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
  String? zone,                 // название реального зала («Зал 1» и т.п.), если гость его выбрал
})
```

### Что рендерит экран

| Элемент | Описание |
|---|---|
| Тотем `bird_totem` | Spring-анимация: scale (600 мс, `elasticOut`) + rotate (600 мс, `easeOut`) |
| Заголовок «ПУТЬ ЗАБРОНИРОВАН» | fadeIn + slideY, задержка 200 мс |
| Подзаголовок | «Ваша заявка успешно отправлена проводникам», задержка 300 мс |
| Карточка деталей | Дата/время, кол-во героев (склонение), зона (если выбрана) |
| Список «Сценарий после отправки» | 3 шага |
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

В форме бронирования всегда виден дисклеймер: «Важно: в приложении нет онлайн-оплаты и списания депозита» (`lib/screens/booking_screen.dart`). Поле «Требуется депозит при бронировании» было удалено из админки и API как избыточное — оплата через приложение не принимается в принципе.

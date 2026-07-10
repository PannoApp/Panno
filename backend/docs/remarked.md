# Remarked CRM — API-клиенты

> **Зачем:** брони, меню и стоп-лист переезжают в CRM Remarked (см.
> `backend/docs/telegram_removal.md` — Telegram-уведомления менеджерам и часть
> логики броней становятся избыточными после этого переезда).
> Этот файл объясняет, что такое `apps/remarked/`, откуда взяты
> `REMARKED_API_TOKEN`/`REMARKED_POINT_ID` в `.env` и как их поменять,
> чтобы через полгода никто не гадал.

## Что это

`apps/remarked/` — Django-приложение с тонкими HTTP-клиентами к API Remarked.
Модели/вьюхи/urls намеренно не используются — это просто библиотека клиентов,
которую импортируют другие приложения (`bookings`, `menu` и т.д.) и Celery-таски.

- `apps/remarked/client.py` — `RemarkedMobileClient` и `RemarkedReservesClient`
  (низкоуровневый транспорт).
- `apps/remarked/reserves_client.py` — `ReservesClient`: высокоуровневая
  обёртка над `RemarkedReservesClient` с кешированием токена и типизированными
  методами брони — см. раздел «ReservesClient» ниже. Используйте её, а не
  `RemarkedReservesClient` напрямую, для любой работы с бронями.
- `apps/remarked/exceptions.py` — `RemarkedAPIError`.

## REMARKED_API_TOKEN / REMARKED_POINT_ID

Обе переменные читаются в `config/settings/base.py` и обязательны (без них
Django не запустится — как `SECRET_KEY`).

- **`REMARKED_API_TOKEN`** — статический API-токен точки (заведения), выданный
  в личном кабинете Remarked. Это НЕ временный токен из метода `GetToken`
  (см. ниже) — он не истекает и настроен один раз для интеграции.
- **`REMARKED_POINT_ID`** — ID заведения (`point`) в Remarked, к которому
  привязан токен.

Текущие значения в `.env`/`.env.example` (`REMARKED_API_TOKEN=5a3c...`,
`REMARKED_POINT_ID=303450`) выданы командой Remarked под интеграцию Panno.
Если токен перевыпустят или сменится заведение — обновить оба файла и
задеплоить заново (перечитываются только при рестарте процесса Django/Celery).

`.env.prod.example` эти переменные пока не содержит — при заведении боевого
контура их нужно будет добавить туда/в секреты сервера отдельно.

## RemarkedMobileClient (api/v2)

```python
from apps.remarked.client import RemarkedMobileClient

client = RemarkedMobileClient()
menu = client._call('/store/menu/by-type', {'point': client.point_id, 'type': 'app', 'version': '2.0'})
stop_list = client._call('/store/nomenclature/stop-list', {'point': client.point_id})
guest = client._call(
    '/store/customer/get-info',
    {'phone': '+79999999999'},
    extra_headers={'X-source': 'app'},
)
```

- База: `https://app.remarked.ru/api/v2`.
- Обычный REST: один эндпоинт = один путь (`/store/menu/by-type`,
  `/store/nomenclature/stop-list`, `/store/customer/get-info` и т.д.).
- Авторизация — заголовок `Authorization: Bearer <REMARKED_API_TOKEN>`,
  добавляется автоматически внутри `_call()`.
- `point` в теле запроса нужен не всем методам (например, не нужен
  `/store/customer/get-info`) — клиент его сам не подставляет, передавайте
  явно там, где того требует конкретный эндпоинт (см. `openapi.json` в корне
  репозитория — спека `MOBILE API V2.0`).

## RemarkedReservesClient (api/v1)

В спеке `RESERVES API V1` (`openapi.json`/спека, приложенная к задаче) внутри
одного домена уживаются **два разных формата вызова** — не перепутать:

1. **`POST /ApiReservesWidget`** — JSON-RPC-*подобный*, но не настоящий
   JSON-RPC 2.0: тело — просто `{"method": "<Method>", ...payload}`, без
   `jsonrpc`/`id`. Сюда попадают все "обычные" методы: `GetToken`,
   `GetDaysStates`, `GetSlots`, `GetSMSCode`, `CreateReserve`,
   `GetReservesByPhone`, `ChangeReserveStatus`, `GetReserveByID`,
   `IsReserveRead`. Вызываются через `_call(method_name, **payload)`.

   `RemarkedReservesClient` (`apps/remarked/client.py`) — это только транспорт
   уровня `_call(method_name, **payload)`: собирает тело `{"method": ..., ...}`
   и шлёт его. Он **не знает про токен** и не подставляет его сам — токен
   передаётся вызывающим кодом как обычный `token=...` в payload. Не
   используйте этот класс напрямую для брони — токен здесь не статический
   `REMARKED_API_TOKEN` (см. предупреждение ниже), а временный, полученный
   через `GetToken`, и его нужно кешировать и обновлять при 401. Всё это уже
   сделано в `ReservesClient` — см. следующий раздел.

2. **`POST /api`** (метод `getEventTags`) — уже настоящий JSON-RPC 2.0:
   `{"jsonrpc": 2, "method": "ReservesWidgetApi.getEventTags", "params": {...}, "id": "..."}`.
   Вызывается отдельным методом `get_event_tags()` на `RemarkedReservesClient`,
   а не через `_call()`.

   ```python
   from apps.remarked.client import RemarkedReservesClient

   client = RemarkedReservesClient()
   tags = client.get_event_tags()
   ```

> ⚠️ Старая версия этого файла утверждала, что для `GetSlots`/`CreateReserve`/
> и т.д. можно передавать статический `REMARKED_API_TOKEN` как `token=...`, а
> `GetToken` вызывать не нужно. Это оказалось неверно — не было проверено
> живьём на момент написания. Живой тест (см. «Проверено на боевом Remarked»
> ниже) показал, что для брони нужен именно временный токен из `GetToken`.

## ReservesClient (рекомендуемый способ работы с бронями)

`ReservesClient` (`apps/remarked/reserves_client.py`) — то, что реально нужно
импортировать для работы с бронями (используется в `apps/bookings/tasks.py`).
Оборачивает `RemarkedReservesClient`, сам получает и кеширует временный
токен через `GetToken`, автоматически повторяет вызов один раз с обновлённым
токеном при 401.

```python
from apps.remarked.reserves_client import ReservesClient

reserves = ReservesClient()

slots = reserves.get_slots(
    reserve_date_period={'from': '2026-07-10', 'to': '2026-07-10'},
    guests_count=2,
)

result = reserves.create_reserve({
    'name': 'Алихан', 'phone': '+77001234567',
    'date': '2026-07-10', 'time': '19:30',
    'guests_count': 2, 'source': 'mobile_app',
})
reserve_id = result['reserve_id']

reserve = reserves.get_reserve_by_id(reserve_id)
reserves.change_reserve_status(reserve_id, 'canceled', cancel_reason='other')
```

Доступные методы: `get_token(force_refresh=False)`, `get_slots(...)`,
`get_days_states(...)`, `create_reserve(reserve, confirm_code=None,
request_id=None)` (генерирует свой `request_id`-UUID, если не передан —
это Idempotency-Key на уровне Remarked, не путать с нашим собственным
заголовком `Idempotency-Key` в `POST /api/v1/bookings/`),
`get_reserves_by_phone(phone, **kwargs)`, `change_reserve_status(reserve_id,
status, cancel_reason=None)`, `get_reserve_by_id(reserve_id)`.

Токен кешируется в Redis (`remarked_reserve_token:{point}`, TTL 15 минут —
в спеке TTL не указан, значение подобрано консервативно). При 401 от любого
метода токен обновляется принудительно и вызов повторяется один раз; если
и обновлённый токен получает 401 — ошибка пробрасывается дальше как обычно
(retry всей задачи — уже на уровне `@shared_task`/`autoretry_for`, как и у
остальных интеграций).

## Ошибки

Оба клиента кидают `apps.remarked.exceptions.RemarkedAPIError` при:

- non-2xx HTTP-статусе;
- `{"status": "error", "code": ..., "message": ...}` в теле (формат ошибок
  `/ApiReservesWidget` и `/store/*` — схемы `Error400`/`Error401`/`Error429`
  в спеках);
- `{"error": {"code": ..., "message": ...}}` в теле (формат ошибок настоящего
  JSON-RPC на `/api`).

`RemarkedAPIError` содержит `code`, `message`, `status_code`.

## Проверено на боевом Remarked (2026-07-08)

Спека местами не совпадает с реальным поведением API. Ниже — что проверено
живыми запросами к `https://app.remarked.ru` (point `303450`), а не только
по документации.

### `customer/get-info`: несуществующий гость → `400`, не `404`

Спека подразумевает, что для не найденного гостя логично ждать `404` или
сообщение с «не найден». В реальности для точки `303450` — обычный
`{"status":"error","code":400,"message":"Bad Request"}`, тот же самый и для
404, и для генерически некорректного запроса. Различить их по телу нельзя,
поэтому `RemarkedMobileClient.get_info_by_phone()` трактует **любой** `400`
как «гость не найден» (не как ошибку) — см. код и тест
`test_get_info_by_phone_generic_400_returns_none` в `apps/remarked/tests.py`.

### `customer/create`: подтверждён **partial update**

Открытый вопрос (см. `docs/users.md`) был закрыт прямым экспериментом:

1. `customer/create` с `name`+`surname`+`gender`+`email` на новом номере —
   гость создан, все четыре поля сохранились.
2. Тот же номер, `customer/create` **повторно**, но уже без `surname` и
   `email` (ровно то, что шлёт `create_or_update()`, когда у пользователя
   пустые `last_name`/`email`).
3. `get-info` после шага 2 — `surname` и `email` **не обнулились**, остались
   от шага 1.

Вывод: `customer/create` обновляет только переданные поля, непереданные не
трогает. Значит, поля, которые могли быть заполнены вручную в CRM
(`comment`, `tags`, `subscriptions`) или считаются самим Remarked
(`bonuses`, `amount_spent`), обновлениями профиля из приложения не
затираются — текущая реализация `create_or_update()` (шлёт только известные
поля) корректна и не нуждается в доработке «слать полное состояние».

`comment`, в свою очередь, похоже вообще не устанавливается через
`customer/create` — попытка его записать через API молча не сохранилась
(осталось `null`). Это, возможно, read-only поле, доступное только из панели
Remarked — не проверялось глубже, так как для интеграции Panno не требуется.

### `GetToken` (Reserves API v1): `point` — required по спеке, но ломает вызов

Спека `GetToken` (`bookings.json`) помечает `point` как обязательное поле.
Живой тест показал обратное: `{"method": "GetToken", "point": 303450}`
(и с верным, и без Authorization-заголовка) отвечает
`{"status":"error","message":"Unknown error"}`, а `{"method": "GetToken"}`
без `point` — валидным токеном. Этим токеном успешно проверены `GetSlots`
(вернул реальные слоты) и `GetReservesByPhone` (вернул реальные брони) — то
есть скоуп токена и без явного `point` уже соответствует нашей точке.
`ReservesClient.get_token()` (`apps/remarked/reserves_client.py`) намеренно
не передаёт `point` в `GetToken` вопреки спеке — см. докстринг класса.

### `GetSlots.rooms`: реальные залы/столы — есть, просто не в тех полях, где искали

Изначально казалось, что API Remarked не даёт способа получить список залов и
столов ресторана без создания брони (см. старую версию `docs/bookings.md`,
раздел «Задел на будущее»). Это оказалось неверным выводом — причина была в
том, что первый живой запрос печатался с обрезкой (`[:6000]` символов), а
`rooms` в ответе `GetSlots` идёт **после** большого массива `slots` и просто
не попадал в напечатанный кусок.

Полный (не обрезанный) ответ `GetSlots(with_rooms=True)` содержит **4** ключа
верхнего уровня: `status`, `slots`, `rooms`, `interiors` (последний пока
`null`). `rooms` — это `{room_id: {id, name, tables: {table_id: {id, name,
capacity, min_capacity, max_capacity, room_id, image_url, description}}}}`:

```json
"rooms": {
  "304": {"id": 304, "name": "Зал 1", "tables": {
    "4361": {"id": 4361, "name": "4", "capacity": 2, "min_capacity": 1, "max_capacity": 2, "room_id": 304}
  }},
  "305": {"id": 305, "name": "Зал 2", "tables": {
    "4384": {"id": 4384, "name": "202", "capacity": 2, "min_capacity": 1, "max_capacity": 2, "room_id": 305}
  }}
}
```

Для точки `303450` реально два зала — **«Зал 1»** и **«Зал 2»** (не «Главный
зал/Терраса/Приват», которые были придуманы в первой версии `TableBooking`).
У каждого стола есть два разных числа: `id` (внутренний, «случайный» на вид —
`4361`, `296465492592631`) и `name` (человеческий номер, который видно в зале
— `«4»`, `«202»`). `tables_ids` в самих слотах `GetSlots.slots[].tables_ids` —
это всегда `id`, не `name`.

Эта структура не зависит от даты/кол-ва гостей (`GetSlots` — единственный
метод, который её отдаёт, отдельного «списка залов» в Reserves API нет),
поэтому `apps/bookings/services.py::get_rooms()` дёргает `GetSlots` с
минимальными параметрами (сегодня, 1 гость) только чтобы получить `rooms`, и
кеширует результат на час — подробности использования (`list_zones()`,
`check_availability(zone_id=)`, `pick_table_for_room()`, эндпоинт
`GET /api/v1/bookings/zones/`) см. `backend/docs/bookings.md#залы`.

### Полный цикл брони проверен живьём: `CreateReserve` → `GetReserveByID` → `ChangeReserveStatus`

После починки `GetToken` весь цикл проверен реальными запросами (не моками):
`CreateReserve` создал бронь на тестовый номер (`reserve_id` вернулся сразу),
`ChangeReserveStatus` сразу же перевёл её в `canceled`, `GetReserveByID`
подтвердил `inner_status: "canceled"` — то есть маппинг статусов в
`apps/bookings/tasks.py::sync_reserve_statuses` (`docs/bookings.md`) проверен
не только моками, но и на реальном ответе Remarked.

## Таймауты и повторы

- `timeout=10` секунд на каждый HTTP-запрос.
- Один автоматический повтор **только** при сетевой ошибке (обрыв соединения,
  DNS, таймаут) — не при HTTP-ошибке или бизнес-ошибке в теле ответа.
- Повторы бизнес-логики (например, весь Celery-таск при 5xx от Remarked)
  клиент не делает — это задача вызывающего кода
  (`autoretry_for`/`max_retries` на уровне `@shared_task`, как это уже сделано
  в `apps/bookings/tasks.py` для Telegram).

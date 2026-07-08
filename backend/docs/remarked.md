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

- `apps/remarked/client.py` — `RemarkedMobileClient` и `RemarkedReservesClient`.
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

   ```python
   from apps.remarked.client import RemarkedReservesClient

   client = RemarkedReservesClient()
   slots = client._call(
       'GetSlots',
       token=client.token,
       reserve_date_period={'from': '2026-07-10', 'to': '2026-07-10'},
       guests_count=2,
   )
   ```

   Токен — статический `REMARKED_API_TOKEN`, передавайте его явно как
   `token=client.token` в payload методов, которые его требуют (все, кроме
   `GetToken`). Отдельно вызывать `GetToken` для получения токена **не нужно**
   при обычной работе — токен уже выдан и не истекает.

2. **`POST /api`** (метод `getEventTags`) — уже настоящий JSON-RPC 2.0:
   `{"jsonrpc": 2, "method": "ReservesWidgetApi.getEventTags", "params": {...}, "id": "..."}`.
   Вызывается отдельным методом `get_event_tags()`, а не через `_call()`.

   ```python
   tags = client.get_event_tags()
   ```

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

## Таймауты и повторы

- `timeout=10` секунд на каждый HTTP-запрос.
- Один автоматический повтор **только** при сетевой ошибке (обрыв соединения,
  DNS, таймаут) — не при HTTP-ошибке или бизнес-ошибке в теле ответа.
- Повторы бизнес-логики (например, весь Celery-таск при 5xx от Remarked)
  клиент не делает — это задача вызывающего кода
  (`autoretry_for`/`max_retries` на уровне `@shared_task`, как это уже сделано
  в `apps/bookings/tasks.py` для Telegram).

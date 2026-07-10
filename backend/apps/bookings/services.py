from datetime import date

from django.conf import settings

from utils.cache import safe_cache_get, safe_cache_set

from apps.remarked.client import RemarkedReservesClient
from apps.remarked.reserves_client import ReservesClient

# Синхронный вызов в теле запроса (гость ждёт ответа прямо в форме брони) —
# короткий таймаут по аналогии с REMARKED_LOGIN_SYNC_TIMEOUT в apps/users/services.py.
REMARKED_AVAILABILITY_TIMEOUT = 5

# Залы/столы меняются гораздо реже, чем занятость — кешируем на час отдельно
# от посуточного кеша доступности (см. views.py::_availability_cache_key_fmt).
ROOMS_CACHE_KEY_FMT = 'remarked_rooms:{point}'
ROOMS_CACHE_TTL = 60 * 60


def _slot_time(slot):
    start_datetime = slot.get('start_datetime', '')
    return start_datetime.split(' ')[-1] if start_datetime else ''


def get_rooms():
    """
    Реальные залы и столы ресторана из Remarked.

    GetSlots — единственный метод, который отдаёт `rooms` (см. docs/bookings.md),
    отдельного «списка залов» в Reserves API нет. Данные о залах не зависят от
    даты/кол-ва гостей, поэтому дёргаем GetSlots с минимальными параметрами
    (сегодня, 1 гость) только чтобы получить `rooms`, и кешируем результат
    на час — незачем повторять этот вызов на каждое открытие формы брони.

    Возвращает {room_id (int): {'id', 'name', 'tables': {table_id (int): {...}}}}.
    Не перехватывает RemarkedAPIError — пробрасывает вызывающему коду.
    """
    cache_key = ROOMS_CACHE_KEY_FMT.format(point=settings.REMARKED_POINT_ID)
    cached = safe_cache_get(cache_key)
    if cached is not None:
        return cached

    reserves = ReservesClient(transport=RemarkedReservesClient(timeout=REMARKED_AVAILABILITY_TIMEOUT))
    today = date.today().isoformat()
    response = reserves.get_slots(
        reserve_date_period={'from': today, 'to': today},
        guests_count=1,
        with_rooms=True,
    )

    rooms = {}
    for room_id_str, room in (response.get('rooms') or {}).items():
        tables = {}
        for table_id_str, table in (room.get('tables') or {}).items():
            tables[int(table_id_str)] = table
        rooms[int(room_id_str)] = {
            'id': room.get('id'),
            'name': room.get('name'),
            'tables': tables,
        }

    safe_cache_set(cache_key, rooms, timeout=ROOMS_CACHE_TTL)
    return rooms


def list_zones():
    """Упрощённый список залов для пикера в приложении: [{'id', 'name'}, ...]."""
    rooms = get_rooms()
    return [{'id': room['id'], 'name': room['name']} for room in rooms.values()]


def _table_ids_for_room(room_id):
    rooms = get_rooms()
    room = rooms.get(room_id)
    if not room:
        return set()
    return set(room['tables'].keys())


def check_availability(date, guests_count, zone_id=None):
    """
    Список слотов на заданную дату для заданного количества гостей.

    Если передан zone_id — `tables_count`/`is_free` пересчитываются только по
    столам этого зала (см. get_rooms). Без zone_id — по всему ресторану, как
    раньше.

    Возвращает [{'time': 'HH:MM:SS', 'is_free': bool, 'tables_count': int}, ...].
    Не перехватывает RemarkedAPIError — пробрасывает вызывающему коду.
    """
    reserves = ReservesClient(transport=RemarkedReservesClient(timeout=REMARKED_AVAILABILITY_TIMEOUT))
    response = reserves.get_slots(
        reserve_date_period={'from': date, 'to': date},
        guests_count=guests_count,
        with_rooms=True,
    )

    zone_table_ids = _table_ids_for_room(zone_id) if zone_id is not None else None

    slots = []
    for slot in response.get('slots', []):
        tables_ids = slot.get('tables_ids') or []
        if zone_table_ids is not None:
            tables_ids = [t for t in tables_ids if t in zone_table_ids]
            tables_count = len(tables_ids)
            is_free = tables_count > 0
        else:
            tables_count = slot.get('tables_count', 0)
            is_free = bool(slot.get('is_free'))

        slots.append({
            'time': _slot_time(slot),
            'is_free': is_free,
            'tables_count': tables_count,
        })
    return slots


def pick_table_for_room(date, time_str, guests_count, room_id):
    """
    Ищет свободный стол в конкретном зале на точные дату/время/кол-во гостей —
    используется при создании брони (create_reserve_in_remarked), чтобы честно
    передать в CreateReserve стол именно из выбранного гостем зала, а не
    полагаться на автоподбор Remarked по всему ресторану.

    Возвращает id стола (int) или None, если подходящего стола не нашлось
    (в т.ч. если зал разобрали между проверкой доступности и созданием брони —
    вызывающий код в этом случае просто не передаёт table_ids, без ошибки).
    """
    zone_table_ids = _table_ids_for_room(room_id)
    if not zone_table_ids:
        return None

    reserves = ReservesClient(transport=RemarkedReservesClient(timeout=REMARKED_AVAILABILITY_TIMEOUT))
    response = reserves.get_slots(
        reserve_date_period={'from': date, 'to': date},
        guests_count=guests_count,
        with_rooms=True,
    )

    for slot in response.get('slots', []):
        if not slot.get('is_free') or _slot_time(slot) != time_str:
            continue
        for table_id in slot.get('tables_ids') or []:
            if table_id in zone_table_ids:
                return table_id
    return None

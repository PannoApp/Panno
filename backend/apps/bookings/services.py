from apps.remarked.client import RemarkedReservesClient
from apps.remarked.reserves_client import ReservesClient

# Синхронный вызов в теле запроса (гость ждёт ответа прямо в форме брони) —
# короткий таймаут по аналогии с REMARKED_LOGIN_SYNC_TIMEOUT в apps/users/services.py.
REMARKED_AVAILABILITY_TIMEOUT = 5


def check_availability(date, guests_count):
    """
    Список слотов на весь ресторан (без фильтра по залу — Remarked не отдаёт
    отдельным методом карту "зал → столы", см. docs/bookings.md) на заданную
    дату для заданного количества гостей.

    with_rooms=True передаём уже сейчас, хотя зальную часть ответа пока не
    используем — задел на будущее (см. docs/bookings.md), стоимость нулевая.

    Возвращает [{'time': 'HH:MM:SS', 'is_free': bool, 'tables_count': int}, ...].
    Не перехватывает RemarkedAPIError — пробрасывает вызывающему коду.
    """
    reserves = ReservesClient(transport=RemarkedReservesClient(timeout=REMARKED_AVAILABILITY_TIMEOUT))
    response = reserves.get_slots(
        reserve_date_period={'from': date, 'to': date},
        guests_count=guests_count,
        with_rooms=True,
    )

    slots = []
    for slot in response.get('slots', []):
        start_datetime = slot.get('start_datetime', '')
        time_part = start_datetime.split(' ')[-1] if start_datetime else ''
        slots.append({
            'time': time_part,
            'is_free': bool(slot.get('is_free')),
            'tables_count': slot.get('tables_count', 0),
        })
    return slots

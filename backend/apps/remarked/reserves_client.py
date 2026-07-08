import logging
import uuid

from utils.cache import safe_cache_get, safe_cache_set

from .client import RemarkedReservesClient
from .exceptions import RemarkedAPIError

logger = logging.getLogger(__name__)

# TTL в спеке Reserves API не указан — ставим консервативные 15 минут и
# подстраховываемся retry-once с принудительным обновлением токена на 401
# от любого метода (см. _call_with_token), а не только на просрочку TTL.
TOKEN_CACHE_TTL = 60 * 15
TOKEN_CACHE_KEY_FMT = 'remarked_reserve_token:{point}'


class ReservesClient:
    """
    Высокоуровневая обёртка над RemarkedReservesClient (api/v1, /ApiReservesWidget):
    кеширует временный токен, полученный через GetToken, в Redis и добавляет
    типизированные методы для брони. Токен из GetToken — не то же самое, что
    статический REMARKED_API_TOKEN (см. apps/remarked/client.py) и передаётся
    в теле остальных методов (`token=...`).

    Проверено эмпирически на боевом Remarked (2026-07-08): `point` у GetToken
    отмечен в спеке как required, но реально с явным `point` (в т.ч. с верным
    REMARKED_POINT_ID) метод отвечает `{"status":"error","message":"Unknown
    error"}`. Без `point` тот же вызов работает и возвращает токен, скоуп
    которого уже корректно соответствует нашей точке — GetSlots/
    GetReservesByPhone с этим токеном возвращают реальные данные. Поэтому
    `get_token()` намеренно не передаёт `point`, несмотря на спеку.
    """

    def __init__(self, transport=None):
        self.transport = transport or RemarkedReservesClient()

    @property
    def _cache_key(self):
        return TOKEN_CACHE_KEY_FMT.format(point=self.transport.point_id)

    def get_token(self, force_refresh=False):
        if not force_refresh:
            cached = safe_cache_get(self._cache_key)
            if cached:
                return cached

        response = self.transport._call('GetToken')
        token = response.get('token')
        if token:
            safe_cache_set(self._cache_key, token, timeout=TOKEN_CACHE_TTL)
        return token

    def _call_with_token(self, method_name, **payload):
        token = self.get_token()
        try:
            return self.transport._call(method_name, token=token, **payload)
        except RemarkedAPIError as exc:
            if exc.status_code == 401:
                logger.warning('Remarked reserve token rejected (401), refreshing and retrying: %s', method_name)
                token = self.get_token(force_refresh=True)
                return self.transport._call(method_name, token=token, **payload)
            raise

    def get_slots(self, reserve_date_period, guests_count, with_rooms=None, slot_duration=None):
        payload = {'reserve_date_period': reserve_date_period, 'guests_count': guests_count}
        if with_rooms is not None:
            payload['with_rooms'] = with_rooms
        if slot_duration is not None:
            payload['slot_duration'] = slot_duration
        return self._call_with_token('GetSlots', **payload)

    def get_days_states(self, reserve_date_period, guests_count):
        return self._call_with_token(
            'GetDaysStates',
            reserve_date_period=reserve_date_period,
            guests_count=guests_count,
        )

    def create_reserve(self, reserve, confirm_code=None, request_id=None):
        payload = {
            'reserve': reserve,
            'request_id': request_id or str(uuid.uuid4()),
        }
        if confirm_code is not None:
            payload['confirm_code'] = confirm_code
        return self._call_with_token('CreateReserve', **payload)

    def get_reserves_by_phone(self, phone, **kwargs):
        return self._call_with_token('GetReservesByPhone', phone=phone, **kwargs)

    def change_reserve_status(self, reserve_id, status, cancel_reason=None):
        payload = {'reserve_id': reserve_id, 'status': status}
        if cancel_reason:
            payload['cancel_reason'] = cancel_reason
        return self._call_with_token('ChangeReserveStatus', **payload)

    def get_reserve_by_id(self, reserve_id):
        return self._call_with_token('GetReserveByID', reserve_id=reserve_id)

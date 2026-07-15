import uuid

from django.conf import settings

from .client import RemarkedReservesClient


class ReservesClient:
    """
    Высокоуровневая обёртка над RemarkedReservesClient (api/v1, /ApiReservesWidget) —
    типизированные методы для брони.

    TODO(remarked-point-bug): GetToken (динамическое получение токена) сейчас
    не используется. Эмпирически проверено (2026-07-08 — 2026-07-14): `point`
    у GetToken отмечен в спеке как required, но при ЛЮБОМ переданном значении
    (наша точка 303450, пример из их же спеки 7999999, случайное число) метод
    ломается с `{"status":"error","message":"Unknown error"}`. Без `point`
    метод не ошибается, но возвращает токен с неверным скоупом — GetSlots этим
    токеном отдаёт несвязанные с реальной схемой зала данные (см.
    docs/remarked.md). Пока используем статический токен Reserves API
    (`REMARKED_RESERVES_STATIC_TOKEN`), полученный напрямую от поддержки
    Remarked — он корректно скоупится на нашу точку. Вернуть на GetToken,
    когда Remarked починит обработку `point`.
    """

    def __init__(self, transport=None):
        self.transport = transport or RemarkedReservesClient()

    def get_token(self, force_refresh=False):
        return settings.REMARKED_RESERVES_STATIC_TOKEN

    def _call_with_token(self, method_name, **payload):
        token = self.get_token()
        return self.transport._call(method_name, token=token, **payload)

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

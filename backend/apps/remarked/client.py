import logging
import uuid

import requests
from django.conf import settings

from .exceptions import RemarkedAPIError

logger = logging.getLogger(__name__)

REQUEST_TIMEOUT = 10


class _BaseRemarkedClient:
    """
    Общий HTTP-транспорт для клиентов Remarked: таймаут, один повтор при сетевой
    ошибке (обрыв соединения/таймаут — не HTTP-ошибка) и разбор ответа/ошибок.

    Ретраи бизнес-логики (например, повтор всей задачи при 5xx) сюда не входят —
    это делается на уровне вызывающих Celery-задач (autoretry_for), клиент лишь
    кидает RemarkedAPIError.
    """

    base_url = None

    def __init__(self, token=None, point_id=None, timeout=None):
        self.token = token or settings.REMARKED_API_TOKEN
        self.point_id = point_id or settings.REMARKED_POINT_ID
        # Переопределяемый таймаут: например, короткий синхронный pull при логине
        # (см. RemarkedGuestService.sync_on_login) не должен ждать полные 10 секунд.
        self.timeout = timeout or REQUEST_TIMEOUT
        self.session = requests.Session()

    def _post(self, path, body, headers=None):
        url = f'{self.base_url}{path}'
        try:
            response = self.session.post(url, json=body, headers=headers, timeout=self.timeout)
        except requests.exceptions.RequestException as exc:
            logger.warning('Remarked request to %s failed (%s), retrying once', url, exc)
            try:
                response = self.session.post(url, json=body, headers=headers, timeout=self.timeout)
            except requests.exceptions.RequestException as exc2:
                raise RemarkedAPIError(message=str(exc2)) from exc2
        return self._parse(response)

    @staticmethod
    def _parse(response):
        try:
            data = response.json()
        except ValueError:
            data = {}

        # /ApiReservesWidget и /store/* отдают ошибку как {"status": "error", "code", "message"}.
        # /api (настоящий JSON-RPC) отдаёт её как {"error": {"code", "message"}} — оба варианта
        # нужно ловить здесь, чтобы вызывающий код везде получал один и тот же RemarkedAPIError.
        rpc_error = data.get('error') if isinstance(data.get('error'), dict) else None
        if not response.ok or data.get('status') == 'error' or rpc_error:
            code = (rpc_error or {}).get('code', data.get('code', response.status_code))
            message = (rpc_error or {}).get('message', data.get('message', response.text))
            raise RemarkedAPIError(code=code, message=message, status_code=response.status_code)
        return data


class RemarkedMobileClient(_BaseRemarkedClient):
    """
    Тонкая обёртка над Remarked Mobile API v2 (https://app.remarked.ru/api/v2) —
    используется для методов гостя, меню и стоп-листа.
    Авторизация — заголовок `Authorization: Bearer <REMARKED_API_TOKEN>`.

    Пример:
        client = RemarkedMobileClient()
        client._call('/store/menu/by-type', {'point': client.point_id, 'type': 'app'})
    """

    base_url = 'https://app.remarked.ru/api/v2'

    def _call(self, path, payload=None, extra_headers=None):
        headers = {'Authorization': f'Bearer {self.token}'}
        if extra_headers:
            headers.update(extra_headers)
        return self._post(path, payload or {}, headers=headers)

    # --- Гость ---

    def get_info_by_phone(self, phone):
        """
        POST /store/customer/get-info по номеру телефона.
        Возвращает словарь с данными гостя (см. CustomerResponse.data в спеке),
        либо None — если гость не найден.

        Проверено эмпирически на боевом Remarked (2026-07-08): для
        несуществующего телефона API отвечает не 404 и не текстом "не найден",
        как можно было бы предположить по спеке, а generic
        `{"status":"error","code":400,"message":"Bad Request"}` — тем же самым
        и для 404, и для 400. Раз тело ответа неотличимо, любой 400/404 здесь
        трактуется как "не найден"; остальные коды (401, 429, 5xx и т.д.)
        пробрасываются дальше как реальная ошибка.
        """
        try:
            response = self._call(
                '/store/customer/get-info',
                {'phone': phone},
                extra_headers={'X-source': 'app'},
            )
        except RemarkedAPIError as exc:
            if exc.status_code in (400, 404) or 'не найден' in (exc.message or '').lower():
                return None
            raise
        return response.get('data') or None

    def create_or_update(self, user, firebase_token=None, device_token=None):
        """
        POST /store/customer/create — по документации Remarked одновременно
        добавляет нового гостя и обновляет уже существующего (матчится по phone).
        Возвращает `gid` — id гостя в Remarked.

        Отправляет полное текущее состояние пользователя (а не только изменённые
        поля): не подтверждено эмпирически, ведёт ли себя этот эндпоинт как
        partial-update или как full-replace, поэтому на всякий случай шлём
        всё, что знаем — так апдейт не затрёт непереданные поля пустыми,
        если Remarked всё же делает full-replace.
        """
        payload = {
            'phone': user.phone,
            'name': user.first_name or user.phone,
            'gender': user.gender,
        }
        if user.last_name:
            payload['surname'] = user.last_name
        if user.email:
            payload['email'] = user.email
        if user.birthday:
            payload['birthday'] = user.birthday.isoformat()
        if firebase_token:
            payload['firebase_token'] = firebase_token
            # Без этого гость технически имеет firebase_token, но не подписан
            # на рассылки по каналу FB в самом Remarked — их push-виджет
            # молча ничего не отправляет такому гостю (разгадано 2026-07-23,
            # проверено живьём: наш собственный тестовый push через FCM API
            # с их же ключом доходил, а их рассылка — нет, именно из-за
            # отсутствия подписки).
            payload['subscriptions'] = {'type': 'firebase', 'sub_type': 'all'}
        if device_token:
            payload['device_token'] = device_token

        data = self._call('/store/customer/create', payload)
        return data.get('gid')


class RemarkedReservesClient(_BaseRemarkedClient):
    """
    Тонкая обёртка над Remarked Reserves API v1 (https://app.remarked.ru/api/v1).

    В спеке этого API два разных формата вызова — не перепутать:
    - `/ApiReservesWidget` — JSON-RPC-подобный, но НЕ настоящий JSON-RPC 2.0:
      тело запроса это просто {"method": "<Method>", ...payload}. Все методы
      (GetToken, GetSlots, CreateReserve, GetReservesByPhone и т.д.) вызываются
      через `_call()`. Токен (REMARKED_API_TOKEN) — статический токен точки,
      выданный в личном кабинете Remarked, его нужно передавать самостоятельно
      как `token=self.token` в payload методов, которые его требуют
      (все, кроме GetToken).
    - `/api` (метод getEventTags) — уже настоящий JSON-RPC 2.0, с полями
      jsonrpc/params/id. Вызывается отдельным методом `get_event_tags()`.

    Заголовок `Referer` (REMARKED_RESERVES_REFERER) обязателен для `GetToken`
    с `point` — без него сервер отвечает `Unknown error` независимо от
    значения `point` (разгадано 2026-07-14, см. docs/remarked.md). Шлём его
    на все методы, а не только GetToken — не помешает.
    """

    base_url = 'https://app.remarked.ru/api/v1'

    def __init__(self, *args, referer=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.referer = referer if referer is not None else settings.REMARKED_RESERVES_REFERER

    def _call(self, method_name, **payload):
        body = {'method': method_name, **payload}
        headers = {'Referer': self.referer} if self.referer else None
        return self._post('/ApiReservesWidget', body, headers=headers)

    def get_event_tags(self, request_id=None):
        body = {
            'method': 'ReservesWidgetApi.getEventTags',
            'jsonrpc': 2,
            'params': {'token': self.token},
            'id': request_id or str(uuid.uuid4()),
        }
        return self._post('/api', body)

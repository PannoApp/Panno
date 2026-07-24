import uuid
from unittest.mock import MagicMock, patch

import requests
from django.core.cache import cache
from django.test import TestCase, override_settings

from .client import RemarkedMobileClient, RemarkedReservesClient
from .exceptions import RemarkedAPIError
from .reserves_client import ReservesClient


def _mock_response(status_code=200, json_data=None, text=''):
    resp = MagicMock()
    resp.status_code = status_code
    resp.ok = 200 <= status_code < 300
    resp.text = text
    resp.json.return_value = json_data if json_data is not None else {}
    return resp


# ---------------------------------------------------------------------------
# RemarkedMobileClient — гость
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
class RemarkedMobileClientGuestTest(TestCase):
    def test_get_info_by_phone_returns_guest_data(self):
        client = RemarkedMobileClient()
        response = _mock_response(200, {'data': {'id': 'gid-1', 'name': 'Алихан'}})
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            result = client.get_info_by_phone('+77001234567')

        self.assertEqual(result['id'], 'gid-1')
        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs['headers']['Authorization'], 'Bearer test-token')
        self.assertEqual(kwargs['headers']['X-source'], 'app')

    def test_get_info_by_phone_404_returns_none(self):
        client = RemarkedMobileClient()
        response = _mock_response(404, {'status': 'error', 'code': 404, 'message': 'Гость не найден'})
        with patch.object(client.session, 'post', return_value=response):
            result = client.get_info_by_phone('+77001234567')
        self.assertIsNone(result)

    def test_get_info_by_phone_not_found_message_returns_none(self):
        """Даже если Remarked вернул 400, а не 404 — текст "не найден" тоже трактуется как отсутствие гостя."""
        client = RemarkedMobileClient()
        response = _mock_response(400, {'status': 'error', 'code': 400, 'message': 'Гость не найден'})
        with patch.object(client.session, 'post', return_value=response):
            result = client.get_info_by_phone('+77001234567')
        self.assertIsNone(result)

    def test_get_info_by_phone_generic_400_returns_none(self):
        """
        Проверено эмпирически на боевом Remarked (2026-07-08): для несуществующего
        гостя реальный ответ — это generic {"code":400,"message":"Bad Request"},
        без "не найден" в тексте. Такой ответ тоже должен трактоваться как
        "гость не найден", а не как ошибка.
        """
        client = RemarkedMobileClient()
        response = _mock_response(400, {'status': 'error', 'code': 400, 'message': 'Bad Request'})
        with patch.object(client.session, 'post', return_value=response):
            result = client.get_info_by_phone('+77001234567')
        self.assertIsNone(result)

    def test_get_info_by_phone_other_error_raises(self):
        client = RemarkedMobileClient()
        response = _mock_response(401, {'status': 'error', 'code': 401, 'message': 'Empty Bearer Token'})
        with patch.object(client.session, 'post', return_value=response):
            with self.assertRaises(RemarkedAPIError):
                client.get_info_by_phone('+77001234567')

    def test_get_info_by_phone_empty_data_returns_none(self):
        client = RemarkedMobileClient()
        response = _mock_response(200, {'data': {}})
        with patch.object(client.session, 'post', return_value=response):
            result = client.get_info_by_phone('+77001234567')
        self.assertIsNone(result)

    def test_create_or_update_returns_gid(self):
        client = RemarkedMobileClient()
        response = _mock_response(200, {'gid': 'gid-42'})
        user = MagicMock(phone='+77001234567', first_name='Алихан', last_name='', email='', birthday=None, gender='male')
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            gid = client.create_or_update(user)

        self.assertEqual(gid, 'gid-42')
        _, kwargs = mock_post.call_args
        sent_body = kwargs['json']
        self.assertEqual(sent_body['phone'], '+77001234567')
        self.assertEqual(sent_body['name'], 'Алихан')
        self.assertEqual(sent_body['gender'], 'male')
        self.assertNotIn('surname', sent_body)
        self.assertNotIn('email', sent_body)

    def test_create_or_update_falls_back_to_phone_as_name(self):
        """Remarked требует непустой `name` — до заполнения анкеты подставляем телефон."""
        client = RemarkedMobileClient()
        response = _mock_response(200, {'gid': 'gid-1'})
        user = MagicMock(phone='+77001234567', first_name='', last_name='', email='', birthday=None, gender='not_specified')
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client.create_or_update(user)

        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs['json']['name'], '+77001234567')

    def test_create_or_update_includes_optional_fields_when_present(self):
        client = RemarkedMobileClient()
        response = _mock_response(200, {'gid': 'gid-1'})
        birthday = MagicMock()
        birthday.isoformat.return_value = '1995-05-20'
        user = MagicMock(
            phone='+77001234567', first_name='Алихан', last_name='Сейткали',
            email='a@example.com', birthday=birthday, gender='male',
        )
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client.create_or_update(user, firebase_token='fcm-1', device_token='dev-1')

        _, kwargs = mock_post.call_args
        body = kwargs['json']
        self.assertEqual(body['surname'], 'Сейткали')
        self.assertEqual(body['email'], 'a@example.com')
        self.assertEqual(body['birthday'], '1995-05-20')
        self.assertEqual(body['firebase_token'], 'fcm-1')
        self.assertEqual(body['device_token'], 'dev-1')
        self.assertEqual(body['subscriptions'], {'type': 'firebase', 'sub_type': 'all'})

    def test_create_or_update_omits_subscriptions_without_firebase_token(self):
        """
        Без firebase_token подписывать не на что — Remarked (2026-07-23)
        подтвердил, что без subscriptions гость не получает их push-рассылки,
        даже если firebase_token у него уже был передан раньше.
        """
        client = RemarkedMobileClient()
        response = _mock_response(200, {'gid': 'gid-1'})
        user = MagicMock(phone='+77001234567', first_name='Алихан', last_name='', email='', birthday=None, gender='male')
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client.create_or_update(user, device_token='dev-1')

        _, kwargs = mock_post.call_args
        self.assertNotIn('subscriptions', kwargs['json'])

    def test_timeout_override_used(self):
        client = RemarkedMobileClient(timeout=3)
        self.assertEqual(client.timeout, 3)

    def test_default_timeout(self):
        client = RemarkedMobileClient()
        self.assertEqual(client.timeout, 10)


# ---------------------------------------------------------------------------
# RemarkedReservesClient
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345, REMARKED_RESERVES_REFERER='1.2.3.4')
class RemarkedReservesClientTest(TestCase):
    def test_call_sends_method_in_body(self):
        client = RemarkedReservesClient()
        response = _mock_response(200, {'status': 'success', 'token': 'abc'})
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client._call('GetToken', point=client.point_id)

        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs['json']['method'], 'GetToken')
        self.assertEqual(kwargs['json']['point'], client.point_id)
        self.assertNotIn('jsonrpc', kwargs['json'])

    def test_call_sends_referer_header(self):
        """
        Разгадано 2026-07-14: GetToken с point ломался из-за отсутствия
        Referer, не из-за самого point — см. docs/remarked.md.
        """
        client = RemarkedReservesClient()
        response = _mock_response(200, {'status': 'success', 'token': 'abc'})
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client._call('GetToken', point=client.point_id)

        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs['headers']['Referer'], '1.2.3.4')

    @override_settings(REMARKED_RESERVES_REFERER='')
    def test_no_referer_header_when_not_configured(self):
        client = RemarkedReservesClient()
        response = _mock_response(200, {'status': 'success', 'token': 'abc'})
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client._call('GetToken', point=client.point_id)

        _, kwargs = mock_post.call_args
        self.assertIsNone(kwargs['headers'])

    def test_get_event_tags_uses_real_jsonrpc_format(self):
        client = RemarkedReservesClient()
        response = _mock_response(200, {'jsonrpc': 2, 'result': {'status': 'success', 'eventTags': []}})
        with patch.object(client.session, 'post', return_value=response) as mock_post:
            client.get_event_tags()

        _, kwargs = mock_post.call_args
        body = kwargs['json']
        self.assertEqual(body['jsonrpc'], 2)
        self.assertIn('params', body)
        self.assertIn('id', body)
        self.assertEqual(body['method'], 'ReservesWidgetApi.getEventTags')

    def test_jsonrpc_error_response_raises(self):
        client = RemarkedReservesClient()
        response = _mock_response(200, {'jsonrpc': 2, 'error': {'code': -32601, 'message': 'Method not found'}})
        with patch.object(client.session, 'post', return_value=response):
            with self.assertRaises(RemarkedAPIError):
                client.get_event_tags()

    def test_status_error_response_raises(self):
        client = RemarkedReservesClient()
        response = _mock_response(200, {'status': 'error', 'code': 400, 'message': 'Bad Request'})
        with patch.object(client.session, 'post', return_value=response):
            with self.assertRaises(RemarkedAPIError):
                client._call('CreateReserve', token='t')


# ---------------------------------------------------------------------------
# Общий транспорт: таймаут и повтор при сетевой ошибке
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
class RemarkedBaseClientRetryTest(TestCase):
    def test_retries_once_on_network_error(self):
        client = RemarkedMobileClient()
        success_response = _mock_response(200, {'data': {}})
        with patch.object(
            client.session, 'post',
            side_effect=[requests.exceptions.ConnectionError('boom'), success_response],
        ) as mock_post:
            client._call('/store/nomenclature/stop-list', {'point': client.point_id})
        self.assertEqual(mock_post.call_count, 2)

    def test_raises_after_second_network_failure(self):
        client = RemarkedMobileClient()
        with patch.object(
            client.session, 'post',
            side_effect=requests.exceptions.ConnectionError('boom'),
        ):
            with self.assertRaises(RemarkedAPIError):
                client._call('/store/nomenclature/stop-list', {'point': client.point_id})


# ---------------------------------------------------------------------------
# ReservesClient — кеш токена в Redis
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
class ReservesClientTokenCacheTest(TestCase):
    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_get_token_calls_get_token_with_point_and_caches_result(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'token': 'tok-1'}) as mock_call:
            token = reserves.get_token()

        self.assertEqual(token, 'tok-1')
        mock_call.assert_called_once_with('GetToken', point=12345)
        self.assertEqual(cache.get('remarked_reserve_token:12345'), 'tok-1')

    def test_get_token_uses_cached_value_without_calling_transport(self):
        reserves = ReservesClient()
        cache.set('remarked_reserve_token:12345', 'cached-tok', timeout=900)

        with patch.object(reserves.transport, '_call') as mock_call:
            token = reserves.get_token()

        self.assertEqual(token, 'cached-tok')
        mock_call.assert_not_called()

    def test_force_refresh_bypasses_cache_and_overwrites_it(self):
        reserves = ReservesClient()
        cache.set('remarked_reserve_token:12345', 'stale-tok', timeout=900)

        with patch.object(reserves.transport, '_call', return_value={'token': 'fresh-tok'}) as mock_call:
            token = reserves.get_token(force_refresh=True)

        self.assertEqual(token, 'fresh-tok')
        mock_call.assert_called_once_with('GetToken', point=12345)
        self.assertEqual(cache.get('remarked_reserve_token:12345'), 'fresh-tok')

    def test_different_points_use_different_cache_keys(self):
        cache.set('remarked_reserve_token:12345', 'tok-for-12345', timeout=900)
        other = ReservesClient(transport=RemarkedReservesClient(point_id=99999))

        with patch.object(other.transport, '_call', return_value={'token': 'tok-for-99999'}) as mock_call:
            token = other.get_token()

        self.assertEqual(token, 'tok-for-99999')
        mock_call.assert_called_once_with('GetToken', point=99999)
        self.assertEqual(cache.get('remarked_reserve_token:99999'), 'tok-for-99999')


# ---------------------------------------------------------------------------
# ReservesClient — retry-once на 401 с обновлением токена
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
class ReservesClientRetryOn401Test(TestCase):
    def setUp(self):
        cache.clear()
        cache.set('remarked_reserve_token:12345', 'stale-tok', timeout=900)

    def tearDown(self):
        cache.clear()

    def test_401_triggers_single_retry_with_refreshed_token(self):
        reserves = ReservesClient()
        error = RemarkedAPIError(code=401, message='Empty Bearer Token', status_code=401)
        with patch.object(
            reserves.transport, '_call',
            side_effect=[error, {'token': 'fresh-tok'}, {'status': 'success', 'slots': []}],
        ) as mock_call:
            result = reserves.get_slots({'from': '2026-07-10', 'to': '2026-07-10'}, guests_count=2)

        self.assertEqual(result['status'], 'success')
        self.assertEqual(mock_call.call_count, 3)
        # 1) GetSlots с протухшим токеном (401) → 2) GetToken (обновление) → 3) GetSlots с новым токеном
        self.assertEqual(mock_call.call_args_list[0].args[0], 'GetSlots')
        self.assertEqual(mock_call.call_args_list[0].kwargs['token'], 'stale-tok')
        self.assertEqual(mock_call.call_args_list[1].args[0], 'GetToken')
        self.assertEqual(mock_call.call_args_list[2].kwargs['token'], 'fresh-tok')
        self.assertEqual(cache.get('remarked_reserve_token:12345'), 'fresh-tok')

    def test_second_401_after_refresh_is_not_retried_again(self):
        """Retry-once — если и обновлённый токен получает 401, ошибка пробрасывается."""
        reserves = ReservesClient()
        error = RemarkedAPIError(code=401, message='Empty Bearer Token', status_code=401)
        with patch.object(
            reserves.transport, '_call',
            side_effect=[error, {'token': 'fresh-tok'}, error],
        ):
            with self.assertRaises(RemarkedAPIError):
                reserves.get_slots({'from': 'x', 'to': 'y'}, guests_count=2)

    def test_non_401_error_propagates_without_retry(self):
        reserves = ReservesClient()
        error = RemarkedAPIError(code=400, message='Bad Request', status_code=400)
        with patch.object(reserves.transport, '_call', side_effect=error) as mock_call:
            with self.assertRaises(RemarkedAPIError):
                reserves.get_slots({'from': 'x', 'to': 'y'}, guests_count=2)
        mock_call.assert_called_once()


# ---------------------------------------------------------------------------
# ReservesClient — типизированные методы
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
class ReservesClientTypedMethodsTest(TestCase):
    def setUp(self):
        cache.clear()
        cache.set('remarked_reserve_token:12345', 'tok-a', timeout=900)

    def tearDown(self):
        cache.clear()

    def test_get_slots_sends_expected_payload(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success', 'slots': []}) as mock_call:
            reserves.get_slots({'from': '2026-07-10', 'to': '2026-07-10'}, guests_count=2, with_rooms=True)
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['token'], 'tok-a')
        self.assertEqual(kwargs['reserve_date_period'], {'from': '2026-07-10', 'to': '2026-07-10'})
        self.assertEqual(kwargs['guests_count'], 2)
        self.assertTrue(kwargs['with_rooms'])

    def test_get_days_states_sends_expected_payload(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success'}) as mock_call:
            reserves.get_days_states({'from': '2026-07-10', 'to': '2026-07-12'}, guests_count=4)
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['reserve_date_period'], {'from': '2026-07-10', 'to': '2026-07-12'})
        self.assertEqual(kwargs['guests_count'], 4)

    def test_create_reserve_generates_request_id_when_missing(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success', 'reserve_id': 1}) as mock_call:
            reserves.create_reserve({
                'name': 'Test', 'phone': '+79999999999', 'date': '2026-07-10',
                'time': '19:00', 'guests_count': 2,
            })
        _, kwargs = mock_call.call_args
        self.assertIn('request_id', kwargs)
        uuid.UUID(kwargs['request_id'])  # не бросает — валидный UUID

    def test_create_reserve_uses_provided_request_id(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success'}) as mock_call:
            reserves.create_reserve({'name': 'Test'}, request_id='fixed-id')
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['request_id'], 'fixed-id')

    def test_create_reserve_includes_confirm_code_when_provided(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success'}) as mock_call:
            reserves.create_reserve({'name': 'Test'}, confirm_code=1234)
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['confirm_code'], 1234)

    def test_get_reserves_by_phone_passes_through_kwargs(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'reserves': []}) as mock_call:
            reserves.get_reserves_by_phone('+77001234567', limit='10', sort_by='id')
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['phone'], '+77001234567')
        self.assertEqual(kwargs['limit'], '10')
        self.assertEqual(kwargs['sort_by'], 'id')

    def test_change_reserve_status_includes_cancel_reason_when_provided(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success'}) as mock_call:
            reserves.change_reserve_status(123, 'canceled', cancel_reason='other')
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['reserve_id'], 123)
        self.assertEqual(kwargs['status'], 'canceled')
        self.assertEqual(kwargs['cancel_reason'], 'other')

    def test_change_reserve_status_omits_cancel_reason_when_absent(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call', return_value={'status': 'success'}) as mock_call:
            reserves.change_reserve_status(123, 'confirmed')
        _, kwargs = mock_call.call_args
        self.assertNotIn('cancel_reason', kwargs)

    def test_get_reserve_by_id_sends_expected_payload(self):
        reserves = ReservesClient()
        response = {'reserve': {'name': 'Иван', 'inner_status': 'confirmed'}}
        with patch.object(reserves.transport, '_call', return_value=response) as mock_call:
            result = reserves.get_reserve_by_id(456)
        _, kwargs = mock_call.call_args
        self.assertEqual(kwargs['token'], 'tok-a')
        self.assertEqual(kwargs['reserve_id'], 456)
        self.assertEqual(result['reserve']['inner_status'], 'confirmed')

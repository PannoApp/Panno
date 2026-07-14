import uuid
from unittest.mock import MagicMock, patch

import requests
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

    def test_timeout_override_used(self):
        client = RemarkedMobileClient(timeout=3)
        self.assertEqual(client.timeout, 3)

    def test_default_timeout(self):
        client = RemarkedMobileClient()
        self.assertEqual(client.timeout, 10)


# ---------------------------------------------------------------------------
# RemarkedReservesClient
# ---------------------------------------------------------------------------

@override_settings(REMARKED_API_TOKEN='test-token', REMARKED_POINT_ID=12345)
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
# ReservesClient — статический токен (временный обход GetToken, см.
# reserves_client.py docstring)
# ---------------------------------------------------------------------------

@override_settings(REMARKED_RESERVES_STATIC_TOKEN='static-tok')
class ReservesClientStaticTokenTest(TestCase):
    def test_get_token_returns_configured_static_token_without_calling_transport(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call') as mock_call:
            token = reserves.get_token()

        self.assertEqual(token, 'static-tok')
        mock_call.assert_not_called()

    def test_force_refresh_still_returns_same_static_token(self):
        reserves = ReservesClient()
        with patch.object(reserves.transport, '_call') as mock_call:
            token = reserves.get_token(force_refresh=True)

        self.assertEqual(token, 'static-tok')
        mock_call.assert_not_called()

    def test_errors_from_transport_propagate_without_retry(self):
        reserves = ReservesClient()
        error = RemarkedAPIError(code=400, message='Bad Request', status_code=400)
        with patch.object(reserves.transport, '_call', side_effect=error) as mock_call:
            with self.assertRaises(RemarkedAPIError):
                reserves.get_slots({'from': 'x', 'to': 'y'}, guests_count=2)
        mock_call.assert_called_once()


# ---------------------------------------------------------------------------
# ReservesClient — типизированные методы
# ---------------------------------------------------------------------------

@override_settings(REMARKED_RESERVES_STATIC_TOKEN='tok-a')
class ReservesClientTypedMethodsTest(TestCase):
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

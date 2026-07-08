from unittest.mock import MagicMock, patch

import requests
from django.test import TestCase, override_settings

from .client import RemarkedMobileClient, RemarkedReservesClient
from .exceptions import RemarkedAPIError


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

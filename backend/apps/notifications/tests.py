from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import UserDevice

User = get_user_model()


def make_user(phone='+77001234567'):
    return User.objects.create_user(phone=phone)


# ---------------------------------------------------------------------------
# POST /api/notifications/device/register/
# ---------------------------------------------------------------------------

class RegisterDeviceViewTest(APITestCase):
    def setUp(self):
        self.user = make_user('+77001111111')

    def _auth(self, user=None):
        refresh = RefreshToken.for_user(user or self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_register_new_device_returns_201(self):
        self._auth()
        response = self.client.post('/api/notifications/device/register/', {
            'fcm_token': 'token_abc_123',
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('message', response.data)

    def test_register_new_device_creates_db_record(self):
        self._auth()
        self.client.post('/api/notifications/device/register/', {'fcm_token': 'token_xyz'})
        self.assertTrue(UserDevice.objects.filter(fcm_token='token_xyz', user=self.user).exists())

    def test_register_existing_token_relinks_to_current_user_returns_200(self):
        other = make_user('+77002222222')
        UserDevice.objects.create(user=other, fcm_token='shared_token')
        self._auth()
        response = self.client.post('/api/notifications/device/register/', {
            'fcm_token': 'shared_token',
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Token should now belong to self.user
        device = UserDevice.objects.get(fcm_token='shared_token')
        self.assertEqual(device.user, self.user)

    def test_register_unauthenticated_returns_401(self):
        response = self.client.post('/api/notifications/device/register/', {
            'fcm_token': 'some_token',
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_register_without_token_returns_400(self):
        self._auth()
        response = self.client.post('/api/notifications/device/register/', {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('fcm_token', response.data)

    def test_one_user_can_have_multiple_devices(self):
        self._auth()
        self.client.post('/api/notifications/device/register/', {'fcm_token': 'token_phone'})
        self.client.post('/api/notifications/device/register/', {'fcm_token': 'token_tablet'})
        self.assertEqual(UserDevice.objects.filter(user=self.user).count(), 2)


# ---------------------------------------------------------------------------
# UserDevice model
# ---------------------------------------------------------------------------

class UserDeviceModelTest(TestCase):
    def setUp(self):
        self.user = make_user('+77003333333')

    def test_str(self):
        device = UserDevice.objects.create(user=self.user, fcm_token='tok')
        self.assertIn(str(self.user.pk), str(device))

    def test_fcm_token_is_unique(self):
        from django.db import IntegrityError
        UserDevice.objects.create(user=self.user, fcm_token='unique_tok')
        with self.assertRaises(IntegrityError):
            UserDevice.objects.create(user=self.user, fcm_token='unique_tok')


# ---------------------------------------------------------------------------
# Celery task: send_push_notification
# ---------------------------------------------------------------------------

class SendPushNotificationTaskTest(TestCase):
    def setUp(self):
        self.user = make_user('+77004444444')

    @patch('apps.notifications.tasks.messaging')
    def test_skips_if_no_devices(self, mock_messaging):
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B')
        mock_messaging.send_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_sends_to_all_devices(self, mock_messaging):
        UserDevice.objects.create(user=self.user, fcm_token='tok1')
        UserDevice.objects.create(user=self.user, fcm_token='tok2')

        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 2
        mock_messaging.send_multicast.return_value = mock_response

        from apps.notifications.tasks import send_push_notification
        result = send_push_notification(user_id=self.user.pk, title='Заголовок', body='Текст')

        mock_messaging.send_multicast.assert_called_once()
        # Inspect constructor call args, not mock instance attributes
        _, kwargs = mock_messaging.MulticastMessage.call_args
        self.assertIn('tok1', kwargs['tokens'])
        self.assertIn('tok2', kwargs['tokens'])
        self.assertEqual(result, 2)

    @patch('apps.notifications.tasks.messaging')
    def test_removes_invalid_tokens_on_failure(self, mock_messaging):
        UserDevice.objects.create(user=self.user, fcm_token='valid_tok')
        UserDevice.objects.create(user=self.user, fcm_token='invalid_tok')

        failed_resp = MagicMock()
        failed_resp.success = False

        ok_resp = MagicMock()
        ok_resp.success = True

        mock_response = MagicMock()
        mock_response.failure_count = 1
        mock_response.success_count = 1
        mock_response.responses = [ok_resp, failed_resp]
        mock_messaging.send_multicast.return_value = mock_response

        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B')

        # The second token ('invalid_tok') should be deleted
        remaining = list(UserDevice.objects.filter(user=self.user).values_list('fcm_token', flat=True))
        self.assertIn('valid_tok', remaining)
        self.assertNotIn('invalid_tok', remaining)

    @patch('apps.notifications.tasks.messaging')
    def test_passes_data_dict_to_message(self, mock_messaging):
        UserDevice.objects.create(user=self.user, fcm_token='tok')

        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 1
        mock_messaging.send_multicast.return_value = mock_response

        extra = {'booking_id': '7', 'status': 'confirmed'}

        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', data=extra)

        _, kwargs = mock_messaging.MulticastMessage.call_args
        self.assertEqual(kwargs['data'], extra)

    @patch('apps.notifications.tasks.messaging')
    def test_empty_data_defaults_to_empty_dict(self, mock_messaging):
        UserDevice.objects.create(user=self.user, fcm_token='tok')

        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 1
        mock_messaging.send_multicast.return_value = mock_response

        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B')

        _, kwargs = mock_messaging.MulticastMessage.call_args
        self.assertEqual(kwargs['data'], {})

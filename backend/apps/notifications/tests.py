from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
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
        response = self.client.post('/api/v1/notifications/device/register/', {
            'fcm_token': 'token_abc_123',
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('message', response.data)

    def test_register_new_device_creates_db_record(self):
        self._auth()
        self.client.post('/api/v1/notifications/device/register/', {'fcm_token': 'token_xyz'})
        self.assertTrue(UserDevice.objects.filter(fcm_token='token_xyz', user=self.user).exists())

    def test_register_existing_token_relinks_to_current_user_returns_200(self):
        other = make_user('+77002222222')
        UserDevice.objects.create(user=other, fcm_token='shared_token')
        self._auth()
        response = self.client.post('/api/v1/notifications/device/register/', {
            'fcm_token': 'shared_token',
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Token should now belong to self.user
        device = UserDevice.objects.get(fcm_token='shared_token')
        self.assertEqual(device.user, self.user)

    def test_register_unauthenticated_returns_401(self):
        response = self.client.post('/api/v1/notifications/device/register/', {
            'fcm_token': 'some_token',
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_register_without_token_returns_400(self):
        self._auth()
        response = self.client.post('/api/v1/notifications/device/register/', {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('fcm_token', response.data)

    def test_one_user_can_have_multiple_devices(self):
        self._auth()
        self.client.post('/api/v1/notifications/device/register/', {'fcm_token': 'token_phone'})
        self.client.post('/api/v1/notifications/device/register/', {'fcm_token': 'token_tablet'})
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
        mock_messaging.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_sends_to_all_devices(self, mock_messaging):
        UserDevice.objects.create(user=self.user, fcm_token='tok1')
        UserDevice.objects.create(user=self.user, fcm_token='tok2')

        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 2
        mock_messaging.send_each_for_multicast.return_value = mock_response

        from apps.notifications.tasks import send_push_notification
        result = send_push_notification(user_id=self.user.pk, title='Заголовок', body='Текст')

        mock_messaging.send_each_for_multicast.assert_called_once()
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
        mock_messaging.send_each_for_multicast.return_value = mock_response

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
        mock_messaging.send_each_for_multicast.return_value = mock_response

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
        mock_messaging.send_each_for_multicast.return_value = mock_response

        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B')

        _, kwargs = mock_messaging.MulticastMessage.call_args
        self.assertEqual(kwargs['data'], {})


# ---------------------------------------------------------------------------
# send_push_notification: category preference filtering
# ---------------------------------------------------------------------------

class SendPushNotificationCategoryTest(TestCase):
    def setUp(self):
        self.user = make_user('+77005555555')
        UserDevice.objects.create(user=self.user, fcm_token='cat_tok')

    @patch('apps.notifications.tasks.messaging')
    def test_skips_when_notify_events_disabled(self, mock_messaging):
        self.user.notify_events = False
        self.user.save()
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', category='events')
        mock_messaging.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_skips_when_notify_promotions_disabled(self, mock_messaging):
        self.user.notify_promotions = False
        self.user.save()
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', category='promotions')
        mock_messaging.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_skips_when_notify_closed_events_disabled(self, mock_messaging):
        self.user.notify_closed_events = False
        self.user.save()
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', category='closed_events')
        mock_messaging.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_sends_when_category_is_none(self, mock_messaging):
        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 1
        mock_messaging.send_each_for_multicast.return_value = mock_response
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', category=None)
        mock_messaging.send_each_for_multicast.assert_called_once()

    @patch('apps.notifications.tasks.messaging')
    def test_sends_when_category_unknown(self, mock_messaging):
        # Unknown categories bypass preference checks
        mock_response = MagicMock()
        mock_response.failure_count = 0
        mock_response.success_count = 1
        mock_messaging.send_each_for_multicast.return_value = mock_response
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=self.user.pk, title='T', body='B', category='unknown_cat')
        mock_messaging.send_each_for_multicast.assert_called_once()

    @patch('apps.notifications.tasks.messaging')
    def test_returns_early_when_user_does_not_exist(self, mock_messaging):
        from apps.notifications.tasks import send_push_notification
        send_push_notification(user_id=999999, title='T', body='B', category='events')
        mock_messaging.send_each_for_multicast.assert_not_called()


# ---------------------------------------------------------------------------
# Celery task: send_bulk_push_notification
# ---------------------------------------------------------------------------

class SendBulkPushNotificationTaskTest(TestCase):
    def setUp(self):
        self.user1 = make_user('+77006666661')
        self.user2 = make_user('+77006666662')
        # Регистрируем устройства: без них фильтрация по UserDevice исключит пользователей
        UserDevice.objects.create(user=self.user1, fcm_token='tok_bulk_user1')
        UserDevice.objects.create(user=self.user2, fcm_token='tok_bulk_user2')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_queues_one_task_per_user(self, mock_task):
        from apps.notifications.tasks import send_bulk_push_notification
        result = send_bulk_push_notification(
            user_ids=[self.user1.pk, self.user2.pk],
            title='T', body='B',
        )
        self.assertEqual(mock_task.delay.call_count, 2)
        self.assertEqual(result, 2)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_empty_user_ids_queues_nothing(self, mock_task):
        from apps.notifications.tasks import send_bulk_push_notification
        result = send_bulk_push_notification(user_ids=[], title='T', body='B')
        mock_task.delay.assert_not_called()
        self.assertEqual(result, 0)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_passes_category_and_data_to_subtasks(self, mock_task):
        from apps.notifications.tasks import send_bulk_push_notification
        extra_data = {'promo_id': '42'}
        send_bulk_push_notification(
            user_ids=[self.user1.pk],
            title='Акция',
            body='Скидка 20%',
            data=extra_data,
            category='promotions',
        )
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['title'], 'Акция')
        self.assertEqual(kwargs['data'], extra_data)
        self.assertEqual(kwargs['category'], 'promotions')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_filters_out_users_without_devices(self, mock_task):
        """Пользователи без зарегистрированных устройств не получают Celery-задачу."""
        user_no_device = make_user('+77006666663')
        from apps.notifications.tasks import send_bulk_push_notification
        result = send_bulk_push_notification(
            user_ids=[self.user1.pk, user_no_device.pk],
            title='T', body='B',
        )
        # Только user1 имеет устройство — только одна задача
        self.assertEqual(mock_task.delay.call_count, 1)
        self.assertEqual(result, 1)
        called_user_id = mock_task.delay.call_args[1]['user_id']
        self.assertEqual(called_user_id, self.user1.pk)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_all_users_without_devices_queues_nothing(self, mock_task):
        """Если все переданные пользователи без устройств — задачи не создаются."""
        user_a = make_user('+77006666664')
        user_b = make_user('+77006666665')
        from apps.notifications.tasks import send_bulk_push_notification
        result = send_bulk_push_notification(
            user_ids=[user_a.pk, user_b.pk],
            title='T', body='B',
        )
        mock_task.delay.assert_not_called()
        self.assertEqual(result, 0)


# ---------------------------------------------------------------------------
# POST /api/notifications/bulk-push/
# ---------------------------------------------------------------------------

class BulkPushViewTest(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(phone='+77007777771', is_staff=True, role='content_manager')
        self.regular = make_user('+77007777772')

    def _auth(self, user):
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_non_admin_returns_403(self):
        self._auth(self.regular)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'all',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unauthenticated_returns_401(self):
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'all',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_missing_title_returns_400(self):
        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'body': 'B', 'segment': 'all',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('title', response.data)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_segment_all_returns_202(self, mock_task):
        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'Привет', 'body': 'Текст', 'segment': 'all',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        mock_task.delay.assert_called_once()

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_segment_all_queued_count_matches_distinct_device_users(self, mock_task):
        user_a = make_user('+77008888881')
        user_b = make_user('+77008888882')
        UserDevice.objects.create(user=user_a, fcm_token='tok_a1')
        UserDevice.objects.create(user=user_a, fcm_token='tok_a2')  # same user, 2 devices
        UserDevice.objects.create(user=user_b, fcm_token='tok_b1')

        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'all',
        }, format='json')
        self.assertEqual(response.data['queued'], 2)  # 2 distinct users

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_segment_participated_in_event_without_event_id_returns_400(self, mock_task):
        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'participated_in_event',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('event_id', response.data)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_segment_registered_after_without_date_returns_400(self, mock_task):
        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'registered_after',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('registered_after', response.data)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_segment_last_visit_days_returns_202(self, mock_task):
        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B',
            'segment': 'last_visit_days', 'last_visit_days': 30,
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(response.data['segment'], 'last_visit_days')

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_registered_after_excludes_users_without_devices(self, mock_task):
        """
        Сегмент registered_after: пользователи без FCM-устройств не учитываются в queued.
        """
        from django.utils import timezone as tz
        from datetime import date
        user_with_device = make_user('+77009000001')
        UserDevice.objects.create(user=user_with_device, fcm_token='tok_reg_filter')
        make_user('+77009000002')  # пользователь без устройства

        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B',
            'segment': 'registered_after',
            'registered_after': '2000-01-01',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        # В выборке только пользователи с устройствами (admin создан в setUp без устройства)
        _, kwargs = mock_task.delay.call_args
        queued_ids = kwargs['user_ids']
        self.assertIn(user_with_device.pk, queued_ids)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_by_city_excludes_users_without_devices(self, mock_task):
        """
        Сегмент by_city: пользователи без FCM-устройств не учитываются в queued.
        """
        from django.contrib.auth import get_user_model
        U = get_user_model()
        user_with_dev = U.objects.create_user(phone='+77009001001', city='Алматы')
        UserDevice.objects.create(user=user_with_dev, fcm_token='tok_city_filter')
        U.objects.create_user(phone='+77009001002', city='Алматы')  # без устройства

        self._auth(self.admin)
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'by_city', 'city': 'Алматы',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        # queued должен содержать только пользователя с устройством
        self.assertEqual(response.data['queued'], 1)


# ---------------------------------------------------------------------------
# Push weekly rate limit
# ---------------------------------------------------------------------------

class PushWeeklyLimitTest(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(phone='+77020000001')
        UserDevice.objects.create(user=self.user, fcm_token='tok-limit-test')

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    def test_push_within_limit_is_sent(self, mock_msg, mock_cache):
        mock_cache.incr.return_value = 1
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category='events')
        mock_msg.send_each_for_multicast.assert_called_once()
        mock_cache.add.assert_called_once()
        mock_cache.incr.assert_called_once()

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    def test_push_over_limit_is_skipped(self, mock_msg, mock_cache):
        mock_cache.incr.return_value = 4  # already at limit
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category='events')
        mock_msg.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    def test_service_push_ignores_limit(self, mock_msg, mock_cache):
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        # category=None → service push, no limit check
        send_push_notification(self.user.pk, 'T', 'B', category=None)
        mock_msg.send_each_for_multicast.assert_called_once()
        mock_cache.incr.assert_not_called()


# ---------------------------------------------------------------------------
# Push time window
# ---------------------------------------------------------------------------

class PushTimeWindowTest(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(phone='+77021000001')
        UserDevice.objects.create(user=self.user, fcm_token='tok-time-test')

    def _make_local_dt(self, hour):
        from datetime import datetime
        from zoneinfo import ZoneInfo
        tz = ZoneInfo('Asia/Almaty')
        return datetime(2026, 5, 12, hour, 0, 0, tzinfo=tz)

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    @patch('apps.notifications.tasks.timezone')
    def test_push_within_window_is_sent(self, mock_tz, mock_msg, mock_cache):
        mock_tz.localtime.return_value = self._make_local_dt(10)
        mock_tz.now.return_value = self._make_local_dt(10)
        mock_cache.incr.return_value = 1
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category='events')
        mock_msg.send_each_for_multicast.assert_called_once()

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    @patch('apps.notifications.tasks.timezone')
    def test_push_outside_window_is_deferred(self, mock_tz, mock_msg, mock_cache):
        now_dt = self._make_local_dt(2)
        mock_tz.localtime.return_value = now_dt
        mock_tz.now.return_value = now_dt
        from apps.notifications.tasks import send_push_notification
        with patch.object(send_push_notification, 'apply_async') as mock_apply:
            send_push_notification(self.user.pk, 'T', 'B', category='events')
            mock_msg.send_each_for_multicast.assert_not_called()
            mock_apply.assert_called_once()
            eta = mock_apply.call_args[1]['eta']
            self.assertEqual(eta.hour, 9)

    @patch('apps.notifications.tasks.cache')
    @patch('apps.notifications.tasks.messaging')
    @patch('apps.notifications.tasks.timezone')
    def test_service_push_ignores_time_window(self, mock_tz, mock_msg, mock_cache):
        mock_tz.localtime.return_value = self._make_local_dt(2)
        mock_tz.now.return_value = self._make_local_dt(2)
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        # category=None → service push, skips time window check
        send_push_notification(self.user.pk, 'T', 'B', category=None)
        mock_msg.send_each_for_multicast.assert_called_once()


# ---------------------------------------------------------------------------
# PushCampaign: статистика доставки
# ---------------------------------------------------------------------------

class PushCampaignTest(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.admin = User.objects.create_user(phone='+77022000001', role='admin')
        self.user1 = User.objects.create_user(phone='+77022000002')
        self.user2 = User.objects.create_user(phone='+77022000003')
        UserDevice.objects.create(user=self.user1, fcm_token='tok-camp-1')
        UserDevice.objects.create(user=self.user2, fcm_token='tok-camp-2')

    def _auth(self):
        refresh = RefreshToken.for_user(self.admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_bulk_push_creates_campaign(self, mock_task):
        self._auth()
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'Акция недели',
            'body': 'Скидка 20%',
            'segment': 'all',
            'category': 'promotions',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        from apps.notifications.models import PushCampaign
        self.assertEqual(PushCampaign.objects.count(), 1)
        camp = PushCampaign.objects.first()
        self.assertEqual(camp.title, 'Акция недели')
        self.assertEqual(camp.segment, 'all')
        self.assertEqual(camp.total_users, 2)
        self.assertEqual(camp.delivered_count, 0)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_campaign_id_passed_to_task(self, mock_task):
        self._auth()
        self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'all',
        }, format='json')
        from apps.notifications.models import PushCampaign
        camp = PushCampaign.objects.first()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['campaign_id'], camp.pk)

    @patch('apps.notifications.tasks.messaging')
    def test_send_push_updates_campaign_counters(self, mock_msg):
        from apps.notifications.models import PushCampaign
        camp = PushCampaign.objects.create(
            title='T', body='B', segment='all', total_users=1,
        )
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        send_push_notification(
            self.user1.pk, 'T', 'B', campaign_id=camp.pk
        )
        camp.refresh_from_db()
        self.assertEqual(camp.delivered_count, 1)
        self.assertEqual(camp.failed_count, 0)


# ---------------------------------------------------------------------------
# notifications_enabled: глобальный выключатель (ТЗ блок 6)
# ---------------------------------------------------------------------------

class NotificationsEnabledFlagTest(TestCase):
    """
    notifications_enabled=False блокирует маркетинговые пуши, но не сервисные.
    """

    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(phone='+77030000001')
        UserDevice.objects.create(user=self.user, fcm_token='tok-enabled-test')

    @patch('apps.notifications.tasks.messaging')
    def test_marketing_push_skipped_when_notifications_disabled(self, mock_msg):
        """Маркетинговый пуш не уходит, если пользователь глобально отключил уведомления."""
        self.user.notifications_enabled = False
        self.user.save()
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category='promotions')
        mock_msg.send_each_for_multicast.assert_not_called()

    @patch('apps.notifications.tasks.messaging')
    def test_service_push_sent_regardless_of_notifications_enabled(self, mock_msg):
        """Сервисный пуш (category=None) уходит даже при notifications_enabled=False."""
        self.user.notifications_enabled = False
        self.user.save()
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category=None)
        mock_msg.send_each_for_multicast.assert_called_once()

    @patch('apps.notifications.tasks.messaging')
    def test_marketing_push_sent_when_notifications_enabled(self, mock_msg):
        """Маркетинговый пуш уходит при notifications_enabled=True (по умолчанию)."""
        mock_msg.send_each_for_multicast.return_value = MagicMock(
            success_count=1, failure_count=0, responses=[]
        )
        from apps.notifications.tasks import send_push_notification
        send_push_notification(self.user.pk, 'T', 'B', category='events')
        mock_msg.send_each_for_multicast.assert_called_once()


# ---------------------------------------------------------------------------
# Сегмент by_city (ТЗ блок 6 — геолокация)
# ---------------------------------------------------------------------------

class BulkPushByCitySegmentTest(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.admin = User.objects.create_user(phone='+77031000001', role='content_manager', is_staff=True)
        self.almaty_user = User.objects.create_user(phone='+77031000002', city='Алматы')
        self.astana_user = User.objects.create_user(phone='+77031000003', city='Астана')
        self.no_city_user = User.objects.create_user(phone='+77031000004')
        # После добавления фильтрации по UserDevice пользователи без устройств
        # не попадают в рассылку — регистрируем устройства для тестовых пользователей
        UserDevice.objects.create(user=self.almaty_user, fcm_token='tok_almaty')
        UserDevice.objects.create(user=self.astana_user, fcm_token='tok_astana')

    def _auth(self):
        refresh = RefreshToken.for_user(self.admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_by_city_segment_filters_by_city(self, mock_task):
        """Сегмент by_city возвращает только пользователей с совпадающим городом."""
        self._auth()
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'by_city', 'city': 'Алматы',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        # Только almaty_user попадает в выборку
        self.assertEqual(response.data['queued'], 1)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_by_city_segment_exact_match_only(self, mock_task):
        """Пользователи другого города не попадают в выборку."""
        self._auth()
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'by_city', 'city': 'Астана',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(response.data['queued'], 1)  # только astana_user

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_by_city_without_city_param_returns_400(self, mock_task):
        """Без параметра city возвращается 400."""
        self._auth()
        response = self.client.post('/api/v1/notifications/bulk-push/', {
            'title': 'T', 'body': 'B', 'segment': 'by_city',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('city', response.data)

    def test_city_field_saved_via_profile_patch(self):
        """Поле city сохраняется через PATCH /api/v1/users/profile/."""
        from rest_framework_simplejwt.tokens import RefreshToken as RT
        refresh = RT.for_user(self.almaty_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        response = self.client.patch('/api/v1/users/profile/', {'city': 'Шымкент'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.almaty_user.refresh_from_db()
        self.assertEqual(self.almaty_user.city, 'Шымкент')


# ---------------------------------------------------------------------------
# Retry-конфигурация Celery-тасок
# ---------------------------------------------------------------------------

class CeleryRetryConfigTest(TestCase):
    """
    Проверяет, что все Celery-таски notifications настроены на retry.
    При сбое Firebase задача не теряется, а повторяется до max_retries раз.
    """

    def test_send_push_notification_has_retry_config(self):
        from apps.notifications.tasks import send_push_notification
        self.assertEqual(send_push_notification.max_retries, 3)
        self.assertEqual(send_push_notification.default_retry_delay, 60)
        self.assertTrue(send_push_notification.acks_late)

    def test_send_push_notification_reject_on_worker_lost(self):
        """reject_on_worker_lost=True — при гибели воркера задача возвращается в очередь."""
        from apps.notifications.tasks import send_push_notification
        self.assertTrue(send_push_notification.reject_on_worker_lost)

    def test_send_push_notification_autoretry_for_exception(self):
        """autoretry_for=(Exception,) — задача перезапускается при любом исключении."""
        from apps.notifications.tasks import send_push_notification
        self.assertIn(Exception, send_push_notification.autoretry_for)

    def test_send_bulk_push_notification_has_retry_config(self):
        from apps.notifications.tasks import send_bulk_push_notification
        self.assertEqual(send_bulk_push_notification.max_retries, 3)
        self.assertEqual(send_bulk_push_notification.default_retry_delay, 60)
        self.assertTrue(send_bulk_push_notification.acks_late)

    def test_send_bulk_push_notification_reject_on_worker_lost(self):
        """reject_on_worker_lost=True — при гибели воркера задача возвращается в очередь."""
        from apps.notifications.tasks import send_bulk_push_notification
        self.assertTrue(send_bulk_push_notification.reject_on_worker_lost)

    def test_send_bulk_push_notification_autoretry_for_exception(self):
        from apps.notifications.tasks import send_bulk_push_notification
        self.assertIn(Exception, send_bulk_push_notification.autoretry_for)

    @patch('apps.notifications.tasks.messaging')
    def test_firebase_exception_propagates_for_autoretry(self, mock_messaging):
        """
        При исключении от Firebase задача пробрасывает его наружу —
        Celery перехватывает его через autoretry_for и ставит задачу на retry.
        """
        from apps.notifications.tasks import send_push_notification
        user = make_user('+77040000001')
        UserDevice.objects.create(user=user, fcm_token='tok-retry')
        mock_messaging.send_each_for_multicast.side_effect = ConnectionError("Firebase недоступен")
        # При прямом вызове задачи (без Celery-воркера) исключение пробрасывается как есть
        with self.assertRaises(ConnectionError):
            send_push_notification(user_id=user.pk, title='T', body='B')


# =============================================================================
# Firebase startup validation — NotificationsConfig.ready()
# =============================================================================

class FirebaseStartupValidationTest(TestCase):
    """При отсутствующем файле credentials логируется WARNING, приложение не падает."""

    def test_missing_file_logs_warning(self):
        """Если файл не существует — в лог попадает WARNING с указанием пути."""
        import firebase_admin
        from apps.notifications.apps import NotificationsConfig

        config = NotificationsConfig('apps.notifications', __import__('apps.notifications', fromlist=['notifications']))

        with self.settings(FIREBASE_CREDENTIALS_PATH='/nonexistent/path/creds.json'):
            # Сбрасываем firebase_admin, чтобы ready() не пропустил инициализацию
            saved_apps = firebase_admin._apps.copy()
            firebase_admin._apps.clear()

            try:
                with self.assertLogs('apps.notifications.apps', level='WARNING') as cm:
                    config.ready()
                # Убеждаемся что сообщение содержит путь к файлу
                self.assertTrue(any('/nonexistent/path/creds.json' in line for line in cm.output))
            finally:
                # Восстанавливаем состояние firebase_admin
                firebase_admin._apps.update(saved_apps)

    def test_missing_file_does_not_raise(self):
        """Отсутствие файла credentials не бросает исключение — сервер стартует."""
        import firebase_admin
        from apps.notifications.apps import NotificationsConfig

        config = NotificationsConfig('apps.notifications', __import__('apps.notifications', fromlist=['notifications']))

        with self.settings(FIREBASE_CREDENTIALS_PATH='/nonexistent/path/creds.json'):
            saved_apps = firebase_admin._apps.copy()
            firebase_admin._apps.clear()

            try:
                # Не должно бросить никакого исключения
                with self.assertLogs('apps.notifications.apps', level='WARNING'):
                    config.ready()
            finally:
                firebase_admin._apps.update(saved_apps)


# ---------------------------------------------------------------------------
# POST /api/notifications/send-push-via-bot/
# ---------------------------------------------------------------------------

class SendPushViaBotViewTest(APITestCase):
    def setUp(self):
        # We need an admin/content_manager with telegram_id
        self.manager = User.objects.create_user(phone='+77009000010', role='content_manager', telegram_id='123456')
        self.regular = User.objects.create_user(phone='+77009000011', role='', telegram_id='654321')
        self.hall_manager = User.objects.create_user(phone='+77009000012', role='hall_manager', telegram_id='999999')
        # Some target users with devices
        self.user1 = User.objects.create_user(phone='+77009000013')
        self.user2 = User.objects.create_user(phone='+77009000014')
        UserDevice.objects.create(user=self.user1, fcm_token='tok_bot_1')
        UserDevice.objects.create(user=self.user2, fcm_token='tok_bot_2')

    @override_settings(TELEGRAM_WEBHOOK_SECRET='super-secret')
    def test_missing_secret_token_returns_403(self):
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '123456', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @override_settings(TELEGRAM_WEBHOOK_SECRET='super-secret')
    def test_invalid_secret_token_returns_403(self):
        self.client.credentials(HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN='wrong-secret')
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '123456', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @override_settings(TELEGRAM_WEBHOOK_SECRET='super-secret')
    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_valid_secret_token_and_manager_returns_202(self, mock_task):
        self.client.credentials(HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN='super-secret')
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '123456', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(response.data['queued'], 2)
        mock_task.delay.assert_called_once()

    @override_settings(TELEGRAM_WEBHOOK_SECRET='')
    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_no_secret_configured_returns_202(self, mock_task):
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '123456', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_regular_user_telegram_id_returns_403(self, mock_task):
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '654321', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch('apps.notifications.tasks.send_bulk_push_notification')
    def test_hall_manager_user_telegram_id_returns_403(self, mock_task):
        response = self.client.post('/api/v1/notifications/send-push-via-bot/', {
            'manager_telegram_id': '999999', 'title': 'T', 'body': 'B'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


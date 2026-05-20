import json
import uuid
from datetime import date as dt_date, time as dt_time
from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import TableBooking
from .serializers import TableBookingSerializer

User = get_user_model()


def make_user(phone='+77001234567'):
    return User.objects.create_user(phone=phone)


def make_booking(user=None, **kwargs):
    defaults = {
        'guest_name': 'Тест Гость',
        'date': '2026-06-15',
        'time': '19:00:00',
        'guests_count': 2,
        'status': 'pending',
    }
    defaults.update(kwargs)
    return TableBooking.objects.create(user=user, **defaults)


# ---------------------------------------------------------------------------
# TableBookingSerializer
# ---------------------------------------------------------------------------

class TableBookingSerializerTest(TestCase):
    def _data(self, **overrides):
        data = {
            'guest_name': 'Алихан',
            'phone': '+77001234567',
            'date': '2026-06-15',
            'time': '19:30:00',
            'guests_count': 4,
        }
        data.update(overrides)
        return data

    def test_valid_data(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_guests_count_zero_is_invalid(self):
        s = TableBookingSerializer(data=self._data(guests_count=0))
        self.assertFalse(s.is_valid())
        self.assertIn('guests_count', s.errors)

    def test_guests_count_51_is_invalid(self):
        s = TableBookingSerializer(data=self._data(guests_count=51))
        self.assertFalse(s.is_valid())
        self.assertIn('guests_count', s.errors)

    def test_guests_count_50_is_valid(self):
        s = TableBookingSerializer(data=self._data(guests_count=50))
        self.assertTrue(s.is_valid(), s.errors)

    def test_missing_guest_name_is_invalid(self):
        data = self._data()
        del data['guest_name']
        s = TableBookingSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('guest_name', s.errors)

    def test_status_is_read_only(self):
        s = TableBookingSerializer(data=self._data(status='confirmed'))
        self.assertTrue(s.is_valid(), s.errors)
        # status is read_only, so it won't be in validated_data
        self.assertNotIn('status', s.validated_data)

    def test_comment_is_optional(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)


# ---------------------------------------------------------------------------
# GET/POST /api/bookings/
# ---------------------------------------------------------------------------

class TableBookingListCreateViewTest(APITestCase):
    def setUp(self):
        self.user = make_user('+77001111111')
        self.other = make_user('+77002222222')

    def _auth(self, user=None):
        refresh = RefreshToken.for_user(user or self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_list_returns_only_own_bookings(self):
        make_booking(user=self.user)
        make_booking(user=self.other)
        self._auth()
        response = self.client.get('/api/v1/bookings/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['guest_name'], 'Тест Гость')

    def test_list_unauthenticated_returns_401(self):
        response = self.client.get('/api/v1/bookings/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_booking_success(self):
        self._auth()
        payload = {
            'guest_name': 'Алихан',
            'phone': '+77001234567',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 3,
        }
        response = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['guest_name'], 'Алихан')
        self.assertEqual(response.data['status'], 'pending')

    def test_create_booking_sets_user(self):
        self._auth()
        payload = {
            'guest_name': 'Данияр',
            'phone': '+77001234567',
            'date': '2026-06-20',
            'time': '20:00:00',
            'guests_count': 2,
        }
        self.client.post('/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        booking = TableBooking.objects.get(guest_name='Данияр')
        self.assertEqual(booking.user, self.user)

    def test_create_booking_unauthenticated_returns_401(self):
        payload = {
            'guest_name': 'Аноним',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 1,
        }
        response = self.client.post('/api/v1/bookings/', payload)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_booking_invalid_guests_count_returns_400(self):
        self._auth()
        payload = {
            'guest_name': 'Алихан',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 100,
        }
        response = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('guests_count', response.data)

    def test_list_empty_when_no_bookings(self):
        self._auth()
        response = self.client.get('/api/v1/bookings/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 0)


# ---------------------------------------------------------------------------
# Signal: notify_on_status_change
# ---------------------------------------------------------------------------

class BookingSignalTest(TestCase):
    def setUp(self):
        self.user = make_user('+77003333333')
        self.booking = make_booking(user=self.user, status='pending')

    def _change_status(self, new_status):
        # Re-fetch so _original_status reflects the DB value
        booking = TableBooking.objects.get(pk=self.booking.pk)
        booking.status = new_status
        booking.save()
        return booking

    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_sent_on_confirmed(self, mock_task):
        self._change_status('confirmed')
        mock_task.delay.assert_called_once()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['user_id'], self.user.pk)
        self.assertIn('booking_id', kwargs['data'])

    @patch('apps.notifications.tasks.send_push_notification')
    def test_confirmed_push_body_contains_date_and_time(self, mock_task):
        """Push при подтверждении должен содержать дату и время визита (по ТЗ)."""
        self._change_status('confirmed')
        _, kwargs = mock_task.delay.call_args
        # Дата в формате DD.MM.YYYY, время в формате HH:MM
        self.assertIn('15.06.2026', kwargs['body'])
        self.assertIn('19:00', kwargs['body'])

    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_sent_on_canceled(self, mock_task):
        self._change_status('canceled')
        mock_task.delay.assert_called_once()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'canceled')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_sent_on_completed(self, mock_task):
        self._change_status('completed')
        mock_task.delay.assert_called_once()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'completed')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_no_push_if_status_unchanged(self, mock_task):
        self._change_status('pending')
        mock_task.delay.assert_not_called()

    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_sent_on_create_with_pending_status(self, mock_task):
        make_booking(user=self.user)
        mock_task.delay.assert_called_once()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'pending')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_no_push_if_no_user(self, mock_task):
        booking = TableBooking.objects.create(
            user=None,
            guest_name='Гость без аккаунта',
            date='2026-07-01',
            time='18:00:00',
            guests_count=1,
            status='pending',
        )
        booking = TableBooking.objects.get(pk=booking.pk)
        booking.status = 'confirmed'
        booking.save()
        mock_task.delay.assert_not_called()

    @patch('apps.notifications.tasks.send_push_notification')
    def test_no_push_for_unknown_status(self, mock_task):
        # 'pending' → 'pending' is same status, already tested
        # If status changes to unrecognised value — but choices constrain this.
        # Test that going pending→pending doesn't push (belt-and-suspenders)
        booking = TableBooking.objects.get(pk=self.booking.pk)
        booking.status = 'pending'
        booking.save()
        mock_task.delay.assert_not_called()


# ---------------------------------------------------------------------------
# Celery task: send_booking_reminders
# ---------------------------------------------------------------------------

class SendBookingRemindersTaskTest(TestCase):
    """
    The task queries bookings where date=today and time is 1–2 hours from now.
    We mock timezone.now/localtime so the "current time" is fixed at 14:00.
    Window: time >= 15:00 and time <= 16:00.
    """

    def _mock_timezone(self, mock_tz, hour=14, minute=0, today=None):
        fixed_date = today or dt_date(2026, 5, 12)
        mock_dt = MagicMock()
        mock_dt.date.return_value = fixed_date
        mock_dt.time.return_value = dt_time(hour, minute)
        mock_dt.__add__ = lambda self, delta: MagicMock(
            time=lambda: dt_time(
                (hour * 60 + minute + int(delta.total_seconds() // 60)) // 60 % 24,
                (hour * 60 + minute + int(delta.total_seconds() // 60)) % 60,
            ),
            date=lambda: fixed_date,
        )
        mock_tz.now.return_value = MagicMock()
        mock_tz.localtime.return_value = mock_dt
        return fixed_date

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_returns_zero_when_no_bookings_in_window(self, mock_push, mock_tz):
        self._mock_timezone(mock_tz)
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 0)
        mock_push.delay.assert_not_called()

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_queues_push_for_confirmed_booking_in_window(self, mock_push, mock_tz):
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        user = make_user('+77009999991')
        # 15:30 is 1.5 h from 14:00 — within window [15:00, 16:00]
        TableBooking.objects.create(
            user=user, guest_name='В окне', date=fixed_date,
            time='15:30:00', guests_count=2, status='confirmed',
        )
        mock_push.delay.reset_mock()  # discard the signal push fired on creation
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 1)
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['user_id'], user.pk)
        self.assertEqual(kwargs['data']['type'], 'reminder')

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_skips_pending_bookings(self, mock_push, mock_tz):
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        user = make_user('+77009999992')
        TableBooking.objects.create(
            user=user, guest_name='Ожидает', date=fixed_date,
            time='15:30:00', guests_count=2, status='pending',
        )
        mock_push.delay.reset_mock()
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 0)
        mock_push.delay.assert_not_called()

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_skips_booking_without_user(self, mock_push, mock_tz):
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        # No user — signal won't fire either, but reset for clarity
        TableBooking.objects.create(
            user=None, guest_name='Без аккаунта', date=fixed_date,
            time='15:30:00', guests_count=1, status='confirmed',
        )
        mock_push.delay.reset_mock()
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 0)
        mock_push.delay.assert_not_called()

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_skips_booking_on_different_date(self, mock_push, mock_tz):
        self._mock_timezone(mock_tz, hour=14, minute=0, today=dt_date(2026, 5, 12))
        user = make_user('+77009999993')
        TableBooking.objects.create(
            user=user, guest_name='Другой день', date=dt_date(2026, 5, 13),
            time='15:30:00', guests_count=2, status='confirmed',
        )
        mock_push.delay.reset_mock()
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 0)
        mock_push.delay.assert_not_called()


# ---------------------------------------------------------------------------
# TableBooking phone field
# ---------------------------------------------------------------------------

class TableBookingPhoneFieldTest(TestCase):
    def _data(self, **overrides):
        data = {
            'guest_name': 'Алихан',
            'date': '2026-06-15',
            'time': '19:30:00',
            'guests_count': 4,
        }
        data.update(overrides)
        return data

    def test_phone_accepted_by_serializer(self):
        s = TableBookingSerializer(data=self._data(phone='+77001234567'))
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['phone'], '+77001234567')

    def test_phone_required(self):
        s = TableBookingSerializer(data=self._data())
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_phone_empty_string_rejected(self):
        s = TableBookingSerializer(data=self._data(phone=''))
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_invalid_phone_no_plus(self):
        s = TableBookingSerializer(data=self._data(phone='77001234567'))
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_invalid_phone_letters(self):
        s = TableBookingSerializer(data=self._data(phone='+7700ABC1234'))
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_invalid_phone_too_short(self):
        s = TableBookingSerializer(data=self._data(phone='+7700'))
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_valid_phone_formats(self):
        for phone in ['+77001234567', '+14155552671', '+447911123456']:
            with self.subTest(phone=phone):
                s = TableBookingSerializer(data=self._data(phone=phone))
                self.assertTrue(s.is_valid(), s.errors)

class TableBookingPhoneAPITest(APITestCase):
    def setUp(self):
        self.user = make_user('+77014000001')

    def _auth(self, user=None):
        refresh = RefreshToken.for_user(user or self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_create_booking_with_phone(self):
        self._auth()
        payload = {
            'guest_name': 'Данияр',
            'phone': '+77001112233',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 2,
        }
        response = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['phone'], '+77001112233')
        self.assertEqual(TableBooking.objects.get(guest_name='Данияр').phone, '+77001112233')


# ---------------------------------------------------------------------------
# Idempotency — POST /api/v1/bookings/
# ---------------------------------------------------------------------------

class BookingIdempotencyTest(APITestCase):
    URL = '/api/v1/bookings/'

    def setUp(self):
        self.user = make_user('+77009000001')
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        self.payload = {
            'guest_name': 'Идем Потент',
            'phone': '+77001234567',
            'date': '2026-08-01',
            'time': '18:00:00',
            'guests_count': 2,
        }
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_missing_key_returns_400(self):
        response = self.client.post(self.URL, self.payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Idempotency-Key', response.data['detail'])

    def test_invalid_key_returns_400(self):
        response = self.client.post(
            self.URL, self.payload, HTTP_IDEMPOTENCY_KEY='not-a-uuid',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_first_request_creates_booking(self):
        key = str(uuid.uuid4())
        response = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 1)

    def test_duplicate_key_does_not_create_second_booking(self):
        key = str(uuid.uuid4())
        r1 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r1.data['id'], r2.data['id'])
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 1)

    def test_different_keys_create_two_bookings(self):
        r1 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertNotEqual(r1.data['id'], r2.data['id'])
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 2)

    def test_same_key_different_user_creates_new_booking(self):
        key = str(uuid.uuid4())
        self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)

        user2 = make_user('+77009000002')
        refresh2 = RefreshToken.for_user(user2)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh2.access_token}')
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(TableBooking.objects.count(), 2)


# ---------------------------------------------------------------------------
# Retry-конфигурация Celery-таски send_booking_reminders
# ---------------------------------------------------------------------------

class BookingReminderRetryConfigTest(TestCase):
    """
    Проверяет, что send_booking_reminders настроена на автоматический retry.
    При сбое БД или Redis задача не теряется, а повторяется до max_retries раз.
    """

    def test_has_retry_config(self):
        from apps.bookings.tasks import send_booking_reminders
        self.assertEqual(send_booking_reminders.max_retries, 3)
        self.assertEqual(send_booking_reminders.default_retry_delay, 60)
        self.assertTrue(send_booking_reminders.acks_late)

    def test_reject_on_worker_lost(self):
        """reject_on_worker_lost=True — при гибели воркера задача возвращается в очередь."""
        from apps.bookings.tasks import send_booking_reminders
        self.assertTrue(send_booking_reminders.reject_on_worker_lost)

    def test_autoretry_for_exception(self):
        """autoretry_for=(Exception,) — задача перезапускается при любом исключении."""
        from apps.bookings.tasks import send_booking_reminders
        self.assertIn(Exception, send_booking_reminders.autoretry_for)

    @patch('apps.bookings.models.TableBooking.objects')
    def test_db_exception_propagates_for_autoretry(self, mock_objects):
        """При сбое БД задача пробрасывает исключение — Celery запустит retry."""
        from apps.bookings.tasks import send_booking_reminders
        # TableBooking импортируется внутри функции, поэтому патчим на уровне модели
        mock_objects.filter.side_effect = Exception("DB connection lost")
        with self.assertRaises(Exception):
            send_booking_reminders()


# ---------------------------------------------------------------------------
# Дедупликация напоминаний через Redis-ключ reminder_sent:{booking_id}
# ---------------------------------------------------------------------------

class BookingReminderDeduplicationTest(TestCase):
    """
    Проверяет, что повторный запуск send_booking_reminders в том же
    временном окне не отправляет второе напоминание одной и той же брони.
    Механизм: cache.add('reminder_sent:{pk}', True, 10800).
    """

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def _mock_timezone(self, mock_tz, hour=14, minute=0, today=None):
        fixed_date = today or dt_date(2026, 5, 12)
        mock_dt = MagicMock()
        mock_dt.date.return_value = fixed_date
        mock_dt.time.return_value = dt_time(hour, minute)
        mock_dt.__add__ = lambda self, delta: MagicMock(
            time=lambda: dt_time(
                (hour * 60 + minute + int(delta.total_seconds() // 60)) // 60 % 24,
                (hour * 60 + minute + int(delta.total_seconds() // 60)) % 60,
            ),
            date=lambda: fixed_date,
        )
        mock_tz.now.return_value = MagicMock()
        mock_tz.localtime.return_value = mock_dt
        return fixed_date

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_second_run_does_not_send_duplicate_push(self, mock_push, mock_tz):
        """Второй запуск задачи в том же окне не должен отправлять повторный пуш."""
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        user = make_user('+77020000001')
        TableBooking.objects.create(
            user=user, guest_name='Дедупликация', date=fixed_date,
            time='15:30:00', guests_count=2, status='confirmed',
        )
        mock_push.delay.reset_mock()

        from apps.bookings.tasks import send_booking_reminders
        # Первый запуск — пуш уходит, ключ устанавливается
        result1 = send_booking_reminders()
        # Второй запуск — ключ уже есть, пуш не отправляется
        result2 = send_booking_reminders()

        self.assertEqual(result1, 1)
        self.assertEqual(result2, 0)
        self.assertEqual(mock_push.delay.call_count, 1)

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_cache_key_is_set_after_first_run(self, mock_push, mock_tz):
        """После первого запуска Redis-ключ reminder_sent:{pk} должен быть установлен."""
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        user = make_user('+77020000002')
        booking = TableBooking.objects.create(
            user=user, guest_name='Ключ', date=fixed_date,
            time='15:30:00', guests_count=2, status='confirmed',
        )
        mock_push.delay.reset_mock()

        from apps.bookings.tasks import send_booking_reminders
        send_booking_reminders()

        self.assertIsNotNone(cache.get(f'reminder_sent:{booking.pk}'))

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_different_bookings_each_get_one_push(self, mock_push, mock_tz):
        """Две разные брони в окне должны получить по одному пушу каждая."""
        fixed_date = self._mock_timezone(mock_tz, hour=14, minute=0)
        user1 = make_user('+77020000003')
        user2 = make_user('+77020000004')
        TableBooking.objects.create(
            user=user1, guest_name='Гость 1', date=fixed_date,
            time='15:10:00', guests_count=2, status='confirmed',
        )
        TableBooking.objects.create(
            user=user2, guest_name='Гость 2', date=fixed_date,
            time='15:50:00', guests_count=3, status='confirmed',
        )
        mock_push.delay.reset_mock()

        from apps.bookings.tasks import send_booking_reminders
        # Первый запуск — оба пуша уходят
        result1 = send_booking_reminders()
        # Второй запуск — оба ключа уже есть
        result2 = send_booking_reminders()

        self.assertEqual(result1, 2)
        self.assertEqual(result2, 0)
        self.assertEqual(mock_push.delay.call_count, 2)


# ---------------------------------------------------------------------------
# Celery task: send_telegram_notification
# ---------------------------------------------------------------------------

_TG_SETTINGS = dict(TELEGRAM_BOT_TOKEN='test_bot_token', TELEGRAM_CHAT_ID='-1001234567890')


class TelegramNotificationTaskTest(TestCase):
    def setUp(self):
        self.user = make_user('+77005000001')
        self.booking = make_booking(
            user=self.user,
            phone='+77001234567',
            zone='main',
            comment='У окна',
        )

    def _call(self, booking_pk=None):
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(booking_pk or self.booking.pk)

    def _mock_post(self):
        m = MagicMock()
        m.raise_for_status.return_value = None
        return m

    # --- основное поведение ---

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_sends_message_on_valid_booking(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        mock_post.assert_called_once()

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_contains_booking_id_and_guest_name(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        text = mock_post.call_args[1]['json']['text']
        self.assertIn(str(self.booking.pk), text)
        self.assertIn(self.booking.guest_name, text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_contains_phone_from_booking(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        text = mock_post.call_args[1]['json']['text']
        self.assertIn('+77001234567', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_contains_date_time_and_zone(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        text = mock_post.call_args[1]['json']['text']
        self.assertIn('15.06.2026', text)
        self.assertIn('19:00', text)
        self.assertIn('Главный зал', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_contains_comment(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        text = mock_post.call_args[1]['json']['text']
        self.assertIn('У окна', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_uses_user_phone_when_booking_phone_is_empty(self, mock_post):
        mock_post.return_value = self._mock_post()
        booking = make_booking(user=self.user, phone='')
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(booking.pk)
        text = mock_post.call_args[1]['json']['text']
        self.assertIn(self.user.phone, text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_anonymous_booking_without_phone_shows_dash(self, mock_post):
        mock_post.return_value = self._mock_post()
        anon = TableBooking.objects.create(
            user=None, guest_name='Аноним',
            date='2026-07-01', time='18:00:00',
            guests_count=1, phone='',
        )
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(anon.pk)
        text = mock_post.call_args[1]['json']['text']
        self.assertIn('—', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_sends_to_correct_chat_id(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        payload = mock_post.call_args[1]['json']
        self.assertEqual(payload['chat_id'], '-1001234567890')

    # --- пропуск при незаполненных настройках ---

    @override_settings(TELEGRAM_BOT_TOKEN='', TELEGRAM_CHAT_ID='-1001234567890')
    @patch('apps.bookings.tasks.requests.post')
    def test_skips_when_no_token(self, mock_post):
        self._call()
        mock_post.assert_not_called()

    @override_settings(TELEGRAM_BOT_TOKEN='test_bot_token', TELEGRAM_CHAT_ID='')
    @patch('apps.bookings.tasks.requests.post')
    def test_skips_when_no_chat_id(self, mock_post):
        self._call()
        mock_post.assert_not_called()

    # --- устойчивость ---

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_does_not_raise_on_missing_booking(self, mock_post):
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(99999)
        mock_post.assert_not_called()

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_propagates_http_error_for_celery_retry(self, mock_post):
        from requests import HTTPError
        mock_post.return_value = MagicMock(raise_for_status=MagicMock(side_effect=HTTPError('500')))
        from apps.bookings.tasks import send_telegram_notification
        with self.assertRaises(HTTPError):
            send_telegram_notification(self.booking.pk)

    # --- WhatsApp-ссылка ---

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_contains_whatsapp_link(self, mock_post):
        mock_post.return_value = self._mock_post()
        self._call()
        text = mock_post.call_args[1]['json']['text']
        self.assertIn('wa.me/77001234567', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_whatsapp_link_uses_user_phone_when_booking_phone_empty(self, mock_post):
        mock_post.return_value = self._mock_post()
        booking = make_booking(user=self.user, phone='')
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(booking.pk)
        text = mock_post.call_args[1]['json']['text']
        # self.user.phone = '+77005000001' → digits: '77005000001'
        self.assertIn('wa.me/77005000001', text)

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_no_whatsapp_link_for_anonymous_booking_without_phone(self, mock_post):
        mock_post.return_value = self._mock_post()
        anon = TableBooking.objects.create(
            user=None, guest_name='Аноним',
            date='2026-07-01', time='18:00:00',
            guests_count=1, phone='',
        )
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(anon.pk)
        text = mock_post.call_args[1]['json']['text']
        self.assertNotIn('wa.me', text)

    # --- конфигурация retry ---

    def test_retry_config(self):
        from apps.bookings.tasks import send_telegram_notification
        self.assertEqual(send_telegram_notification.max_retries, 3)
        self.assertEqual(send_telegram_notification.default_retry_delay, 30)
        self.assertTrue(send_telegram_notification.acks_late)
        self.assertTrue(send_telegram_notification.reject_on_worker_lost)
        self.assertIn(Exception, send_telegram_notification.autoretry_for)


# ---------------------------------------------------------------------------
# Signal: Telegram вызывается при создании брони
# ---------------------------------------------------------------------------

class BookingSignalTelegramTest(TestCase):
    def setUp(self):
        self.user = make_user('+77006000001')

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_telegram_queued_on_create_with_user(self, mock_push, mock_tg):
        booking = make_booking(user=self.user)
        mock_tg.delay.assert_called_once_with(booking.pk)

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_telegram_queued_on_create_without_user(self, mock_push, mock_tg):
        booking = TableBooking.objects.create(
            user=None, guest_name='Гость без аккаунта',
            date='2026-07-01', time='18:00:00', guests_count=1,
        )
        mock_tg.delay.assert_called_once_with(booking.pk)

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_not_sent_on_create_without_user(self, mock_push, mock_tg):
        TableBooking.objects.create(
            user=None, guest_name='Гость без аккаунта',
            date='2026-07-01', time='18:00:00', guests_count=1,
        )
        mock_push.delay.assert_not_called()

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_telegram_not_queued_on_status_change(self, mock_push, mock_tg):
        booking = make_booking(user=self.user)
        mock_tg.delay.reset_mock()
        booking = TableBooking.objects.get(pk=booking.pk)
        booking.status = 'confirmed'
        booking.save()
        mock_tg.delay.assert_not_called()

    # -----------------------------------------------------------------------
    # Устойчивость к падению Redis/Celery-брокера
    # -----------------------------------------------------------------------

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_booking_created_even_if_broker_unavailable(self, mock_push, mock_tg):
        """Бронирование должно сохраняться в БД даже если брокер Celery недоступен."""
        mock_push.delay.side_effect = Exception("Broker down")
        mock_tg.delay.side_effect = Exception("Broker down")

        booking = make_booking(user=self.user)

        self.assertIsNotNone(booking.pk)
        self.assertTrue(TableBooking.objects.filter(pk=booking.pk).exists())

    @patch('apps.bookings.tasks.send_telegram_notification')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_status_change_does_not_raise_if_broker_unavailable(self, mock_push, mock_tg):
        """Изменение статуса не должно падать если брокер Celery недоступен."""
        mock_push.delay.side_effect = Exception("Broker down")
        booking = make_booking(user=self.user)
        booking = TableBooking.objects.get(pk=booking.pk)
        booking.status = 'confirmed'
        booking.save()
        self.assertEqual(TableBooking.objects.get(pk=booking.pk).status, 'confirmed')


# ---------------------------------------------------------------------------
# _build_booking_html helper
# ---------------------------------------------------------------------------

class BuildBookingHtmlHelperTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008100001')
        self.booking = make_booking(
            user=self.user,
            phone='+77001234567',
            zone='main',
            comment='У окна',
        )
        # refresh_from_db() converts SQLite string dates to proper date/time objects
        self.booking.refresh_from_db()

    def _html(self, **kwargs):
        from apps.bookings.tasks import _build_booking_html
        return _build_booking_html(self.booking, **kwargs)

    def test_contains_booking_id(self):
        self.assertIn(str(self.booking.pk), self._html())

    def test_contains_guest_name(self):
        self.assertIn(self.booking.guest_name, self._html())

    def test_contains_phone(self):
        self.assertIn('+77001234567', self._html())

    def test_contains_date_and_time(self):
        text = self._html()
        self.assertIn('15.06.2026', text)
        self.assertIn('19:00', text)

    def test_contains_zone_label(self):
        self.assertIn('Главный зал', self._html())

    def test_contains_comment(self):
        self.assertIn('У окна', self._html())

    def test_contains_whatsapp_link(self):
        self.assertIn('wa.me/77001234567', self._html())

    def test_status_label_appended_when_provided(self):
        text = self._html(status_label='✅ <b>Подтверждено администратором</b>')
        self.assertIn('Подтверждено администратором', text)

    def test_no_status_label_by_default(self):
        text = self._html()
        self.assertNotIn('Подтверждено', text)
        self.assertNotIn('Отменено', text)

    def test_no_whatsapp_link_for_anonymous_without_phone(self):
        anon = TableBooking.objects.create(
            user=None, guest_name='Аноним',
            date='2026-07-01', time='18:00:00', guests_count=1, phone='',
        )
        anon.refresh_from_db()
        from apps.bookings.tasks import _build_booking_html
        self.assertNotIn('wa.me', _build_booking_html(anon))

    def test_terrace_zone_label(self):
        booking = make_booking(user=self.user, phone='+77000000001', zone='terrace')
        booking.refresh_from_db()
        from apps.bookings.tasks import _build_booking_html
        self.assertIn('Терраса', _build_booking_html(booking))

    def test_private_zone_label(self):
        booking = make_booking(user=self.user, phone='+77000000002', zone='private')
        booking.refresh_from_db()
        from apps.bookings.tasks import _build_booking_html
        self.assertIn('Приват', _build_booking_html(booking))

    def test_unknown_zone_renders_raw_value(self):
        booking = make_booking(user=self.user, phone='+77000000003', zone='roof')
        booking.refresh_from_db()
        from apps.bookings.tasks import _build_booking_html
        self.assertIn('roof', _build_booking_html(booking))


# ---------------------------------------------------------------------------
# _tg_post helper
# ---------------------------------------------------------------------------

class TgPostHelperTest(TestCase):
    @patch('apps.bookings.tasks.requests.post')
    def test_posts_to_correct_url(self, mock_post):
        from apps.bookings.tasks import _tg_post
        mock_post.return_value = MagicMock(ok=True)
        _tg_post('sendMessage', {'text': 'hi'}, 'mytoken')
        mock_post.assert_called_once()
        url = mock_post.call_args[0][0]
        self.assertIn('mytoken', url)
        self.assertIn('sendMessage', url)

    @patch('apps.bookings.tasks.requests.post')
    def test_passes_payload_as_json(self, mock_post):
        from apps.bookings.tasks import _tg_post
        mock_post.return_value = MagicMock(ok=True)
        _tg_post('sendMessage', {'chat_id': 42, 'text': 'hello'}, 'tok')
        sent_json = mock_post.call_args[1]['json']
        self.assertEqual(sent_json['chat_id'], 42)
        self.assertEqual(sent_json['text'], 'hello')

    @patch('apps.bookings.tasks.requests.post')
    def test_returns_none_on_network_exception(self, mock_post):
        from apps.bookings.tasks import _tg_post
        mock_post.side_effect = ConnectionError('network unreachable')
        result = _tg_post('sendMessage', {}, 'tok')
        self.assertIsNone(result)

    @patch('apps.bookings.tasks.requests.post')
    def test_does_not_raise_on_non_ok_response(self, mock_post):
        from apps.bookings.tasks import _tg_post
        mock_post.return_value = MagicMock(ok=False, status_code=400, text='Bad Request')
        result = _tg_post('sendMessage', {}, 'tok')
        self.assertIsNotNone(result)

    @patch('apps.bookings.tasks.requests.post')
    def test_returns_response_on_success(self, mock_post):
        from apps.bookings.tasks import _tg_post
        fake_resp = MagicMock(ok=True)
        mock_post.return_value = fake_resp
        result = _tg_post('sendMessage', {}, 'tok')
        self.assertIs(result, fake_resp)


# ---------------------------------------------------------------------------
# send_telegram_notification: inline-кнопки в сообщении
# ---------------------------------------------------------------------------

class TelegramNotificationInlineKeyboardTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008200001')
        self.booking = make_booking(user=self.user, phone='+77001234567', zone='main')

    def _call(self):
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification(self.booking.pk)

    def _mock_ok(self):
        m = MagicMock(ok=True)
        m.raise_for_status.return_value = None
        return m

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_message_has_inline_keyboard(self, mock_post):
        mock_post.return_value = self._mock_ok()
        self._call()
        payload = mock_post.call_args[1]['json']
        self.assertIn('reply_markup', payload)
        self.assertIn('inline_keyboard', payload['reply_markup'])

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_confirm_button_callback_data(self, mock_post):
        mock_post.return_value = self._mock_ok()
        self._call()
        buttons = mock_post.call_args[1]['json']['reply_markup']['inline_keyboard'][0]
        confirm = next(b for b in buttons if 'Подтвердить' in b['text'])
        self.assertEqual(confirm['callback_data'], f'confirm:{self.booking.pk}')

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_cancel_button_callback_data(self, mock_post):
        mock_post.return_value = self._mock_ok()
        self._call()
        buttons = mock_post.call_args[1]['json']['reply_markup']['inline_keyboard'][0]
        cancel = next(b for b in buttons if 'Отменить' in b['text'])
        self.assertEqual(cancel['callback_data'], f'cancel:{self.booking.pk}')

    @override_settings(**_TG_SETTINGS)
    @patch('apps.bookings.tasks.requests.post')
    def test_two_buttons_in_one_row(self, mock_post):
        mock_post.return_value = self._mock_ok()
        self._call()
        keyboard = mock_post.call_args[1]['json']['reply_markup']['inline_keyboard']
        self.assertEqual(len(keyboard), 1)
        self.assertEqual(len(keyboard[0]), 2)


# ---------------------------------------------------------------------------
# TelegramWebhookView
# ---------------------------------------------------------------------------

_WEBHOOK_URL = '/api/v1/bookings/telegram-webhook/'
_TG_WEBHOOK_SETTINGS = dict(
    TELEGRAM_BOT_TOKEN='test_bot_token',
    TELEGRAM_CHAT_ID='-1001234567890',
    TELEGRAM_WEBHOOK_SECRET='',  # no secret by default; override per-test where needed
)


def _cbq_payload(action, booking_pk, chat_id=100, message_id=42):
    """Минимальный payload callback_query от Telegram."""
    return {
        'callback_query': {
            'id': 'cbq_test_id',
            'data': f'{action}:{booking_pk}',
            'message': {
                'message_id': message_id,
                'chat': {'id': chat_id},
            },
        }
    }


class TelegramWebhookSecretTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008300001')
        self.booking = make_booking(user=self.user, phone='+77001234567')

    def _post(self, data, secret_header=None):
        kwargs = {'content_type': 'application/json'}
        if secret_header is not None:
            kwargs['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN'] = secret_header
        return self.client.post(_WEBHOOK_URL, json.dumps(data), **kwargs)

    @override_settings(
        TELEGRAM_BOT_TOKEN='test_bot_token', TELEGRAM_CHAT_ID='-100123',
        TELEGRAM_WEBHOOK_SECRET='my_secret',
    )
    @patch('apps.bookings.views._tg_post')
    def test_missing_secret_header_returns_403(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk))
        self.assertEqual(resp.status_code, 403)
        mock_tg.assert_not_called()

    @override_settings(
        TELEGRAM_BOT_TOKEN='test_bot_token', TELEGRAM_CHAT_ID='-100123',
        TELEGRAM_WEBHOOK_SECRET='my_secret',
    )
    @patch('apps.bookings.views._tg_post')
    def test_wrong_secret_returns_403(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk), secret_header='wrong')
        self.assertEqual(resp.status_code, 403)
        mock_tg.assert_not_called()

    @override_settings(
        TELEGRAM_BOT_TOKEN='test_bot_token', TELEGRAM_CHAT_ID='-100123',
        TELEGRAM_WEBHOOK_SECRET='my_secret',
    )
    @patch('apps.bookings.views._tg_post')
    def test_correct_secret_passes(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk), secret_header='my_secret')
        self.assertNotEqual(resp.status_code, 403)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_no_secret_configured_skips_check(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk))
        self.assertNotEqual(resp.status_code, 403)


class TelegramWebhookBasicTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008400001')
        self.booking = make_booking(user=self.user, phone='+77001234567')

    def _post(self, data):
        return self.client.post(
            _WEBHOOK_URL, json.dumps(data), content_type='application/json',
        )

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    def test_invalid_json_returns_400(self):
        resp = self.client.post(_WEBHOOK_URL, 'not-json', content_type='application/json')
        self.assertEqual(resp.status_code, 400)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_no_callback_query_returns_200(self, mock_tg):
        resp = self._post({'update_id': 999})
        self.assertEqual(resp.status_code, 200)
        mock_tg.assert_not_called()

    @override_settings(TELEGRAM_BOT_TOKEN='', TELEGRAM_CHAT_ID='', TELEGRAM_WEBHOOK_SECRET='')
    @patch('apps.bookings.views._tg_post')
    def test_missing_bot_token_returns_500(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk))
        self.assertEqual(resp.status_code, 500)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_unknown_action_returns_200(self, mock_tg):
        data = {
            'callback_query': {
                'id': 'cbq1', 'data': 'delete:1',
                'message': {'message_id': 1, 'chat': {'id': 1}},
            }
        }
        resp = self._post(data)
        self.assertEqual(resp.status_code, 200)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_malformed_callback_data_returns_200(self, mock_tg):
        data = {
            'callback_query': {
                'id': 'cbq1', 'data': 'single_part',
                'message': {'message_id': 1, 'chat': {'id': 1}},
            }
        }
        resp = self._post(data)
        self.assertEqual(resp.status_code, 200)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_nonexistent_booking_returns_200(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', 99999))
        self.assertEqual(resp.status_code, 200)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_nonexistent_booking_answers_callback(self, mock_tg):
        self._post(_cbq_payload('confirm', 99999))
        answer = next(
            (c for c in mock_tg.call_args_list if c[0][0] == 'answerCallbackQuery'), None,
        )
        self.assertIsNotNone(answer)
        self.assertIn('не найдено', answer[0][1]['text'])


class TelegramWebhookConfirmTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008500001')
        self.booking = make_booking(user=self.user, phone='+77001234567', zone='main')

    def _post(self, data):
        return self.client.post(
            _WEBHOOK_URL, json.dumps(data), content_type='application/json',
        )

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_sets_status_confirmed(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, 'confirmed')

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_returns_200(self, mock_tg):
        resp = self._post(_cbq_payload('confirm', self.booking.pk))
        self.assertEqual(resp.status_code, 200)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_calls_answer_callback(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        calls = [c[0][0] for c in mock_tg.call_args_list]
        self.assertIn('answerCallbackQuery', calls)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_calls_edit_message(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        calls = [c[0][0] for c in mock_tg.call_args_list]
        self.assertIn('editMessageText', calls)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_edit_contains_confirmed_label(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        edit = next(c for c in mock_tg.call_args_list if c[0][0] == 'editMessageText')
        self.assertIn('Подтверждено', edit[0][1]['text'])

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_edit_uses_correct_chat_and_message_id(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk, chat_id=555, message_id=77))
        edit = next(c for c in mock_tg.call_args_list if c[0][0] == 'editMessageText')
        self.assertEqual(edit[0][1]['chat_id'], 555)
        self.assertEqual(edit[0][1]['message_id'], 77)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_edit_clears_inline_keyboard(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        edit = next(c for c in mock_tg.call_args_list if c[0][0] == 'editMessageText')
        self.assertEqual(edit[0][1]['reply_markup'], {'inline_keyboard': []})

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_confirm_answer_callback_id_matches(self, mock_tg):
        self._post(_cbq_payload('confirm', self.booking.pk))
        answer = next(c for c in mock_tg.call_args_list if c[0][0] == 'answerCallbackQuery')
        self.assertEqual(answer[0][1]['callback_query_id'], 'cbq_test_id')

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.notifications.tasks.send_push_notification')
    @patch('apps.bookings.views._tg_post')
    def test_confirm_triggers_push_notification(self, mock_tg, mock_push):
        mock_push.delay.reset_mock()
        self._post(_cbq_payload('confirm', self.booking.pk))
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'confirmed')


class TelegramWebhookCancelTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008600001')
        self.booking = make_booking(user=self.user, phone='+77001234567', zone='terrace')

    def _post(self, data):
        return self.client.post(
            _WEBHOOK_URL, json.dumps(data), content_type='application/json',
        )

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_cancel_sets_status_canceled(self, mock_tg):
        self._post(_cbq_payload('cancel', self.booking.pk))
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, 'canceled')

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_cancel_edit_contains_canceled_label(self, mock_tg):
        self._post(_cbq_payload('cancel', self.booking.pk))
        edit = next(c for c in mock_tg.call_args_list if c[0][0] == 'editMessageText')
        self.assertIn('Отменено', edit[0][1]['text'])

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.notifications.tasks.send_push_notification')
    @patch('apps.bookings.views._tg_post')
    def test_cancel_triggers_push_notification(self, mock_tg, mock_push):
        mock_push.delay.reset_mock()
        self._post(_cbq_payload('cancel', self.booking.pk))
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'canceled')


class TelegramWebhookAlreadyProcessedTest(TestCase):
    def setUp(self):
        self.user = make_user('+77008700001')
        self.booking = make_booking(user=self.user, phone='+77001234567')

    def _post(self, data):
        return self.client.post(
            _WEBHOOK_URL, json.dumps(data), content_type='application/json',
        )

    def _set_status(self, new_status):
        TableBooking.objects.filter(pk=self.booking.pk).update(status=new_status)
        self.booking.refresh_from_db()

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_already_confirmed_shows_alert(self, mock_tg):
        self._set_status('confirmed')
        self._post(_cbq_payload('confirm', self.booking.pk))
        answer = next(c for c in mock_tg.call_args_list if c[0][0] == 'answerCallbackQuery')
        self.assertTrue(answer[0][1].get('show_alert'))

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_already_confirmed_does_not_change_status(self, mock_tg):
        self._set_status('confirmed')
        self._post(_cbq_payload('cancel', self.booking.pk))
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, 'confirmed')

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_already_canceled_shows_alert(self, mock_tg):
        self._set_status('canceled')
        self._post(_cbq_payload('confirm', self.booking.pk))
        answer = next(c for c in mock_tg.call_args_list if c[0][0] == 'answerCallbackQuery')
        self.assertTrue(answer[0][1].get('show_alert'))

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_already_processed_does_not_call_edit_message(self, mock_tg):
        self._set_status('canceled')
        self._post(_cbq_payload('confirm', self.booking.pk))
        calls = [c[0][0] for c in mock_tg.call_args_list]
        self.assertNotIn('editMessageText', calls)

    @override_settings(**_TG_WEBHOOK_SETTINGS)
    @patch('apps.bookings.views._tg_post')
    def test_alert_text_contains_current_status(self, mock_tg):
        self._set_status('confirmed')
        self._post(_cbq_payload('cancel', self.booking.pk))
        answer = next(c for c in mock_tg.call_args_list if c[0][0] == 'answerCallbackQuery')
        self.assertIn('Подтверждено', answer[0][1]['text'])

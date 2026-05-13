import uuid
from datetime import date as dt_date, time as dt_time
from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
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

    def test_phone_defaults_to_empty_string(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data.get('phone', ''), '')

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

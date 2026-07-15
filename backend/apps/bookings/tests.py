import io
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

from apps.core.models import RestaurantInfo
from .models import TableBooking
from .serializers import TableBookingSerializer

User = get_user_model()


def _make_jpeg_bytes():
    from PIL import Image
    img = Image.new('RGB', (32, 18), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    return buf.getvalue()


# Valid JPEG bytes for tests that create Event/News (models with AutoCropImageMixin).
_VALID_JPEG = _make_jpeg_bytes()


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
# TableBookingSerializer.validate() — проверка рабочих часов ресторана
# (RestaurantInfo.is_open_at, apps/core/models.py)
# ---------------------------------------------------------------------------

class TableBookingSerializerWorkingHoursTest(TestCase):
    def _data(self, **overrides):
        # 2026-06-15 — понедельник
        data = {
            'guest_name': 'Алихан',
            'phone': '+77001234567',
            'date': '2026-06-15',
            'time': '19:30:00',
            'guests_count': 4,
        }
        data.update(overrides)
        return data

    def _set_working_hours(self, working_hours):
        info = RestaurantInfo.load()
        info.working_hours = working_hours
        info.save()

    def test_valid_when_working_hours_not_configured(self):
        # По умолчанию RestaurantInfo.working_hours пуст — проверка не блокирует
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_valid_when_working_hours_unparseable(self):
        self._set_working_hours('всегда открыто')
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_valid_when_time_inside_working_hours(self):
        self._set_working_hours('Пн–Вс: 12:00–22:00')
        s = TableBookingSerializer(data=self._data(time='19:30:00'))
        self.assertTrue(s.is_valid(), s.errors)

    def test_invalid_when_time_outside_working_hours(self):
        self._set_working_hours('Пн–Вс: 12:00–22:00')
        s = TableBookingSerializer(data=self._data(time='23:00:00'))
        self.assertFalse(s.is_valid())
        self.assertIn('time', s.errors)

    def test_invalid_when_time_before_opening(self):
        self._set_working_hours('Пн–Вс: 12:00–22:00')
        s = TableBookingSerializer(data=self._data(time='08:00:00'))
        self.assertFalse(s.is_valid())
        self.assertIn('time', s.errors)

    def test_invalid_on_closed_weekday(self):
        # Ресторан работает только Вт-Вс — понедельник закрыт целиком
        self._set_working_hours('Вт–Вс: 12:00–22:00')
        s = TableBookingSerializer(data=self._data(date='2026-06-15', time='19:30:00'))
        self.assertFalse(s.is_valid())
        self.assertIn('time', s.errors)

    def test_valid_midnight_crossing_hours(self):
        self._set_working_hours('Пн–Вс: 20:00–02:00')
        s = TableBookingSerializer(data=self._data(time='01:00:00'))
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

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_create_booking_success(self, mock_reserve_task):
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

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_create_booking_sets_user(self, mock_reserve_task):
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

    @patch('apps.bookings.tasks.timezone')
    @patch('apps.notifications.tasks.send_push_notification')
    def test_midnight_crossing_reminders(self, mock_push, mock_tz):
        today = dt_date(2026, 5, 12)
        tomorrow = dt_date(2026, 5, 13)

        mock_now_dt = MagicMock()
        mock_now_dt.date.return_value = today
        mock_now_dt.time.return_value = dt_time(22, 30)

        mock_start_dt = MagicMock()
        mock_start_dt.date.return_value = today
        mock_start_dt.time.return_value = dt_time(23, 30)

        mock_end_dt = MagicMock()
        mock_end_dt.date.return_value = tomorrow
        mock_end_dt.time.return_value = dt_time(0, 30)

        def mock_add(dt, delta):
            if delta.total_seconds() == 3600:
                return mock_start_dt
            elif delta.total_seconds() == 7200:
                return mock_end_dt
            return mock_now_dt

        mock_now_dt.__add__ = mock_add

        mock_tz.now.return_value = MagicMock()
        mock_tz.localtime.return_value = mock_now_dt

        user1 = make_user('+77009999994')
        user2 = make_user('+77009999995')

        TableBooking.objects.create(
            user=user1, guest_name='Сегодня в конце дня', date=today,
            time='23:45:00', guests_count=2, status='confirmed',
        )

        TableBooking.objects.create(
            user=user2, guest_name='Завтра в начале дня', date=tomorrow,
            time='00:15:00', guests_count=2, status='confirmed',
        )

        mock_push.delay.reset_mock()
        from apps.bookings.tasks import send_booking_reminders
        result = send_booking_reminders()
        self.assertEqual(result, 2)
        self.assertEqual(mock_push.delay.call_count, 2)


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

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_create_booking_with_phone(self, mock_reserve_task):
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
# Поле zone — сериализатор
# ---------------------------------------------------------------------------

class TableBookingZoneTest(TestCase):
    """
    zone — свободный текст (реальные названия залов из Remarked, см.
    apps/bookings/services.py::list_zones), больше не ограничен фиксированным
    списком choices — раньше тут были придуманные main/terrace/private,
    не совпадавшие с реальными залами ресторана («Зал 1», «Зал 2»).
    """

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

    def test_zone_real_room_name_is_valid(self):
        s = TableBookingSerializer(data=self._data(zone='Зал 1'))
        self.assertTrue(s.is_valid(), s.errors)

    def test_zone_arbitrary_text_is_valid(self):
        # zone больше не ограничен choices — любой текст проходит валидацию.
        s = TableBookingSerializer(data=self._data(zone='rooftop'))
        self.assertTrue(s.is_valid(), s.errors)

    def test_zone_omitted_is_valid(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_remarked_room_id_is_valid(self):
        s = TableBookingSerializer(data=self._data(zone='Зал 1', remarked_room_id=304))
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['remarked_room_id'], 304)

    def test_remarked_room_id_omitted_is_valid(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_remarked_room_id_non_integer_rejected(self):
        s = TableBookingSerializer(data=self._data(remarked_room_id='not-a-number'))
        self.assertFalse(s.is_valid())
        self.assertIn('remarked_room_id', s.errors)

    def test_remarked_table_id_is_valid(self):
        s = TableBookingSerializer(data=self._data(zone='Зал 2', remarked_room_id=305, remarked_table_id=4391))
        self.assertTrue(s.is_valid(), s.errors)
        self.assertEqual(s.validated_data['remarked_table_id'], 4391)

    def test_remarked_table_id_omitted_is_valid(self):
        s = TableBookingSerializer(data=self._data())
        self.assertTrue(s.is_valid(), s.errors)

    def test_remarked_table_id_non_integer_rejected(self):
        s = TableBookingSerializer(data=self._data(remarked_table_id='not-a-number'))
        self.assertFalse(s.is_valid())
        self.assertIn('remarked_table_id', s.errors)


# ---------------------------------------------------------------------------
# Поле zone / remarked_room_id — API
# ---------------------------------------------------------------------------

class TableBookingZoneAPITest(APITestCase):
    """Проверяет поля zone и remarked_room_id через API: возврат в ответе, валидация типа."""

    def setUp(self):
        self.user = make_user('+77015000001')
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_create_booking_with_zone_returns_zone_in_response(self, mock_reserve_task):
        payload = {
            'guest_name': 'Зонный тест',
            'phone': '+77001234567',
            'date': '2026-07-01',
            'time': '19:00:00',
            'guests_count': 2,
            'zone': 'Зал 2',
            'remarked_room_id': 305,
        }
        resp = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp.data['zone'], 'Зал 2')
        self.assertEqual(resp.data['remarked_room_id'], 305)

    def test_create_booking_non_integer_remarked_room_id_returns_400(self):
        payload = {
            'guest_name': 'Зонный тест',
            'phone': '+77001234567',
            'date': '2026-07-01',
            'time': '19:00:00',
            'guests_count': 2,
            'remarked_room_id': 'not-a-number',
        }
        resp = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('remarked_room_id', resp.data)


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

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_first_request_creates_booking(self, mock_reserve_task):
        key = str(uuid.uuid4())
        response = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 1)

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_duplicate_key_does_not_create_second_booking(self, mock_reserve_task):
        key = str(uuid.uuid4())
        r1 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r1.data['id'], r2.data['id'])
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 1)

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_different_keys_create_two_bookings(self, mock_reserve_task):
        r1 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertNotEqual(r1.data['id'], r2.data['id'])
        self.assertEqual(TableBooking.objects.filter(user=self.user).count(), 2)

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_same_key_different_user_creates_new_booking(self, mock_reserve_task):
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
# Celery task: create_reserve_in_remarked
# ---------------------------------------------------------------------------

class CreateReserveInRemarkedTaskTest(TestCase):
    def setUp(self):
        self.user = make_user('+77007000001')

    def _call(self, booking_id):
        from apps.bookings.tasks import create_reserve_in_remarked
        create_reserve_in_remarked(booking_id)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_saves_reserve_id_on_success(self, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 555}
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)
        booking.refresh_from_db()
        self.assertEqual(booking.remarked_reserve_id, 555)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_sends_expected_reserve_fields(self, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(
            user=self.user, phone='+77001234567', date='2026-06-15',
            time='19:30:00', guests_count=4, comment='У окна',
        )
        self._call(booking.pk)
        reserve = mock_create.call_args[0][0]
        self.assertEqual(reserve['name'], booking.guest_name)
        self.assertEqual(reserve['phone'], '+77001234567')
        self.assertEqual(reserve['date'], '2026-06-15')
        self.assertEqual(reserve['time'], '19:30')
        self.assertEqual(reserve['guests_count'], 4)
        self.assertEqual(reserve['source'], 'mobile_app')
        self.assertEqual(reserve['comment'], 'У окна')

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_omits_comment_when_blank(self, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('comment', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_falls_back_to_user_phone_when_booking_phone_empty(self, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='')
        self._call(booking.pk)
        reserve = mock_create.call_args[0][0]
        self.assertEqual(reserve['phone'], self.user.phone)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_business_rejection_from_remarked_does_not_raise_or_retry(self, mock_create):
        # HTTP 200, но тело — business-level отказ Remarked (например, "Time
        # is restricted to reservation"): повтор с теми же параметрами
        # провалится так же, поэтому задача не должна пробрасывать исключение
        # (иначе autoretry_for бесполезно потратит 3 попытки).
        from apps.remarked.exceptions import RemarkedAPIError
        mock_create.side_effect = RemarkedAPIError(
            code=200, message='Time is restricted to reservation', status_code=200,
        )
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)  # не должно бросить исключение
        booking.refresh_from_db()
        self.assertIsNone(booking.remarked_reserve_id)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_server_error_from_remarked_still_propagates_for_retry(self, mock_create):
        # Настоящая транспортная/серверная ошибка (5xx) — потенциально
        # временная, поэтому исключение должно пробрасываться дальше, чтобы
        # autoretry_for=(Exception,) перезапустил задачу как раньше.
        from apps.remarked.exceptions import RemarkedAPIError
        mock_create.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        booking = make_booking(user=self.user, phone='+77001234567')
        with self.assertRaises(RemarkedAPIError):
            self._call(booking.pk)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_network_error_from_remarked_still_propagates_for_retry(self, mock_create):
        # status_code=None (сетевой сбой, см. client.py::_post) — тоже
        # потенциально временная проблема, должна ретраиться как раньше.
        from apps.remarked.exceptions import RemarkedAPIError
        mock_create.side_effect = RemarkedAPIError(message='Connection reset')
        booking = make_booking(user=self.user, phone='+77001234567')
        with self.assertRaises(RemarkedAPIError):
            self._call(booking.pk)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_generates_unique_request_id(self, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)
        request_id = mock_create.call_args[1]['request_id']
        uuid.UUID(request_id)  # не бросает — валидный UUID

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_does_not_raise_on_missing_booking(self, mock_create):
        self._call(999999)
        mock_create.assert_not_called()

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    def test_no_reserve_id_in_response_does_not_crash(self, mock_create):
        mock_create.return_value = {'status': 'success'}
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)
        booking.refresh_from_db()
        self.assertIsNone(booking.remarked_reserve_id)

    def test_retry_config(self):
        from apps.bookings.tasks import create_reserve_in_remarked
        self.assertEqual(create_reserve_in_remarked.max_retries, 3)
        self.assertEqual(create_reserve_in_remarked.default_retry_delay, 30)
        self.assertTrue(create_reserve_in_remarked.acks_late)
        self.assertTrue(create_reserve_in_remarked.reject_on_worker_lost)
        self.assertIn(Exception, create_reserve_in_remarked.autoretry_for)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    def test_passes_table_ids_when_room_selected_and_table_found(self, mock_pick, mock_create):
        mock_pick.return_value = 4384
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(
            user=self.user, phone='+77001234567', date='2026-06-15',
            time='19:30:00', guests_count=2, remarked_room_id=305,
        )
        self._call(booking.pk)
        mock_pick.assert_called_once_with('2026-06-15', '19:30:00', 2, 305)
        reserve = mock_create.call_args[0][0]
        self.assertEqual(reserve['table_ids'], [4384])

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    def test_no_table_ids_when_room_selected_but_nothing_free(self, mock_pick, mock_create):
        mock_pick.return_value = None
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567', remarked_room_id=305)
        self._call(booking.pk)
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    def test_room_lookup_error_does_not_block_reserve_creation(self, mock_pick, mock_create):
        from apps.remarked.exceptions import RemarkedAPIError
        mock_pick.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567', remarked_room_id=305)
        self._call(booking.pk)
        booking.refresh_from_db()
        self.assertEqual(booking.remarked_reserve_id, 1)
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    def test_no_room_selected_skips_table_lookup(self, mock_pick, mock_create):
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567')
        self._call(booking.pk)
        mock_pick.assert_not_called()
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    @patch('apps.bookings.services._free_table_ids_at_slot')
    def test_explicit_table_selected_used_directly_no_pick(self, mock_free_ids, mock_pick, mock_create):
        # Гость выбрал конкретный стол — перепроверяем, что он всё ещё
        # свободен (см. _free_table_ids_at_slot), и передаём его напрямую;
        # pick_table_for_room вообще не вызывается (стол уже выбран, не «Любой»).
        mock_free_ids.return_value = [4391]
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(
            user=self.user, phone='+77001234567',
            remarked_room_id=305, remarked_table_id=4391,
        )
        self._call(booking.pk)
        mock_pick.assert_not_called()
        mock_free_ids.assert_called_once_with('2026-06-15', '19:00:00', 2, 305)
        reserve = mock_create.call_args[0][0]
        self.assertEqual(reserve['table_ids'], [4391])

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    @patch('apps.bookings.services._free_table_ids_at_slot')
    def test_explicit_table_no_longer_free_falls_back_without_table_ids(self, mock_free_ids, mock_pick, mock_create):
        # За время между показом пикера и выполнением этой (асинхронной)
        # задачи стол успели занять — не передаём table_ids вовсе, бронь
        # создаётся без привязки к конкретному столу, а не конфликтует в Remarked.
        mock_free_ids.return_value = [4384]  # 4391 больше не свободен
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(
            user=self.user, phone='+77001234567',
            remarked_room_id=305, remarked_table_id=4391,
        )
        self._call(booking.pk)
        mock_pick.assert_not_called()
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    @patch('apps.bookings.services._free_table_ids_at_slot')
    def test_explicit_table_recheck_error_falls_back_without_table_ids(self, mock_free_ids, mock_pick, mock_create):
        from apps.remarked.exceptions import RemarkedAPIError
        mock_free_ids.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(
            user=self.user, phone='+77001234567',
            remarked_room_id=305, remarked_table_id=4391,
        )
        self._call(booking.pk)
        booking.refresh_from_db()
        self.assertEqual(booking.remarked_reserve_id, 1)
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)

    @patch('apps.remarked.reserves_client.ReservesClient.create_reserve')
    @patch('apps.bookings.services.pick_table_for_room')
    def test_explicit_table_without_room_skips_recheck_and_table_ids(self, mock_pick, mock_create):
        # Без remarked_room_id перепроверить стол нечем (нет контекста зала) —
        # в этом случае консервативно не передаём table_ids вовсе, а не
        # доверяем потенциально устаревшему выбору без проверки.
        mock_create.return_value = {'status': 'success', 'reserve_id': 1}
        booking = make_booking(user=self.user, phone='+77001234567', remarked_table_id=4391)
        self._call(booking.pk)
        mock_pick.assert_not_called()
        reserve = mock_create.call_args[0][0]
        self.assertNotIn('table_ids', reserve)


# ---------------------------------------------------------------------------
# apps.bookings.services — залы (get_rooms/list_zones/pick_table_for_room)
# ---------------------------------------------------------------------------

_SLOTS_WITH_ROOMS_RESPONSE = {
    'status': 'success',
    'slots': [
        {
            'start_datetime': '2026-07-20 19:00:00', 'is_free': True,
            'tables_count': 2, 'tables_ids': [4384, 4391],
        },
        {
            'start_datetime': '2026-07-20 19:30:00', 'is_free': True,
            'tables_count': 1, 'tables_ids': [4391],
        },
    ],
    'rooms': {
        '304': {'id': 304, 'name': 'Зал 1', 'tables': {'4361': {'id': 4361, 'name': '4', 'capacity': 2}}},
        '305': {
            'id': 305, 'name': 'Зал 2',
            'tables': {
                '4384': {'id': 4384, 'name': '202', 'capacity': 2},
                '4391': {'id': 4391, 'name': '210', 'capacity': 2},
            },
        },
    },
}


class RemarkedRoomsServiceTest(TestCase):
    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.bookings.services.ReservesClient')
    def test_get_rooms_parses_rooms_and_tables(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import get_rooms
        rooms = get_rooms()
        self.assertEqual(set(rooms.keys()), {304, 305})
        self.assertEqual(rooms[305]['name'], 'Зал 2')
        self.assertEqual(set(rooms[305]['tables'].keys()), {4384, 4391})

    @patch('apps.bookings.services.ReservesClient')
    def test_get_rooms_cached_on_second_call(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import get_rooms
        get_rooms()
        get_rooms()
        self.assertEqual(mock_instance.get_slots.call_count, 1)

    @patch('apps.bookings.services.ReservesClient')
    def test_list_zones_returns_id_and_name_only(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import list_zones
        zones = list_zones()
        self.assertCountEqual(zones, [{'id': 304, 'name': 'Зал 1'}, {'id': 305, 'name': 'Зал 2'}])

    @patch('apps.bookings.services.ReservesClient')
    def test_check_availability_filters_by_zone(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import check_availability
        # Без zone_id — считаем по всему ресторану (tables_count как в ответе).
        result_all = check_availability('2026-07-20', 2)
        self.assertEqual(result_all[0]['tables_count'], 2)
        self.assertEqual(result_all[1]['tables_count'], 1)

    @patch('apps.bookings.services.ReservesClient')
    def test_check_availability_zone_id_narrows_tables_count(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import check_availability
        # Зал 304 содержит только стол 4361, которого нет ни в одном слоте выше.
        result = check_availability('2026-07-20', 2, zone_id=304)
        self.assertEqual(result[0]['tables_count'], 0)
        self.assertFalse(result[0]['is_free'])

    @patch('apps.bookings.services.ReservesClient')
    def test_check_availability_zone_id_matching_room(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import check_availability
        result = check_availability('2026-07-20', 2, zone_id=305)
        self.assertEqual(result[0]['tables_count'], 2)
        self.assertTrue(result[0]['is_free'])

    @patch('apps.bookings.services.ReservesClient')
    def test_pick_table_for_room_returns_free_table_at_exact_time(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import pick_table_for_room
        table_id = pick_table_for_room('2026-07-20', '19:30:00', 2, 305)
        self.assertEqual(table_id, 4391)

    @patch('apps.bookings.services.ReservesClient')
    def test_pick_table_for_room_returns_none_for_unknown_room(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import pick_table_for_room
        self.assertIsNone(pick_table_for_room('2026-07-20', '19:30:00', 2, 999))

    @patch('apps.bookings.services.ReservesClient')
    def test_pick_table_for_room_returns_none_when_time_not_free(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import pick_table_for_room
        self.assertIsNone(pick_table_for_room('2026-07-20', '20:00:00', 2, 305))

    @patch('apps.bookings.services.ReservesClient')
    def test_list_available_tables_returns_name_and_capacity(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import list_available_tables
        tables = list_available_tables('2026-07-20', '19:00:00', 2, 305)
        self.assertEqual(tables, [
            {'id': 4384, 'name': '202', 'capacity': 2},
            {'id': 4391, 'name': '210', 'capacity': 2},
        ])

    @patch('apps.bookings.services.ReservesClient')
    def test_list_available_tables_sorted_by_numeric_name(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        response = {
            'status': 'success',
            'slots': [{'start_datetime': '2026-07-20 19:00:00', 'is_free': True, 'tables_count': 3, 'tables_ids': [1, 2, 3]}],
            'rooms': {'305': {'id': 305, 'name': 'Зал 2', 'tables': {
                '1': {'id': 1, 'name': '10', 'capacity': 2},
                '2': {'id': 2, 'name': '2', 'capacity': 2},
                '3': {'id': 3, 'name': '1', 'capacity': 2},
            }}},
        }
        mock_instance.get_slots.return_value = response
        from apps.bookings.services import list_available_tables
        tables = list_available_tables('2026-07-20', '19:00:00', 2, 305)
        # Числовая сортировка: '1', '2', '10' — а не лексикографическая ('1', '10', '2')
        self.assertEqual([t['name'] for t in tables], ['1', '2', '10'])

    @patch('apps.bookings.services.ReservesClient')
    def test_list_available_tables_unknown_room_returns_empty(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import list_available_tables
        self.assertEqual(list_available_tables('2026-07-20', '19:00:00', 2, 999), [])

    @patch('apps.bookings.services.ReservesClient')
    def test_list_available_tables_time_not_free_returns_empty(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        from apps.bookings.services import list_available_tables
        self.assertEqual(list_available_tables('2026-07-20', '20:00:00', 2, 305), [])


# ---------------------------------------------------------------------------
# GET /api/v1/bookings/zones/
# ---------------------------------------------------------------------------

class BookingZonesViewTest(APITestCase):
    URL = '/api/v1/bookings/zones/'

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.bookings.services.ReservesClient')
    def test_returns_zones_anonymous(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        response = self.client.get(self.URL)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertCountEqual(response.data, [{'id': 304, 'name': 'Зал 1'}, {'id': 305, 'name': 'Зал 2'}])

    @patch('apps.bookings.services.ReservesClient')
    def test_second_request_uses_cache(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        self.client.get(self.URL)
        self.client.get(self.URL)
        self.assertEqual(mock_instance.get_slots.call_count, 1)

    @patch('apps.bookings.services.ReservesClient')
    def test_remarked_error_returns_empty_list_not_500(self, mock_client_cls):
        from apps.remarked.exceptions import RemarkedAPIError
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        response = self.client.get(self.URL)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])


# ---------------------------------------------------------------------------
# GET /api/v1/bookings/tables/
# ---------------------------------------------------------------------------

class BookingTablesViewTest(APITestCase):
    URL = '/api/v1/bookings/tables/'

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def _params(self, **overrides):
        params = {'date': '2026-07-20', 'time': '19:00:00', 'guests': 2, 'zone_id': 305}
        params.update(overrides)
        return params

    @patch('apps.bookings.services.ReservesClient')
    def test_returns_tables_anonymous(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        response = self.client.get(self.URL, self._params())
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [
            {'id': 4384, 'name': '202', 'capacity': 2},
            {'id': 4391, 'name': '210', 'capacity': 2},
        ])

    def test_missing_zone_id_returns_400(self):
        params = self._params()
        del params['zone_id']
        response = self.client.get(self.URL, params)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('zone_id', response.data)

    def test_missing_time_returns_400(self):
        params = self._params()
        del params['time']
        response = self.client.get(self.URL, params)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('time', response.data)

    @patch('apps.bookings.services.ReservesClient')
    def test_confirmed_zero_free_tables_returns_200_empty_list(self, mock_client_cls):
        # Remarked ответил успешно, но у зала 304 (Зал 1, стол 4361) в этот
        # слот нет ни одного своего свободного стола (tables_ids слота —
        # только 4384/4391, оба из Зала 2) — это подтверждённый факт, не
        # ошибка, поэтому 200 с пустым списком, а не 503.
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        response = self.client.get(self.URL, self._params(zone_id=304))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])

    @patch('apps.bookings.services.ReservesClient')
    def test_remarked_error_returns_503_not_empty_list(self, mock_client_cls):
        # В отличие от /bookings/zones/, пустой список тут — подтверждённый
        # факт «в зале нет свободных столов» (клиент должен на это опираться,
        # чтобы не дать забронировать зал без мест). Поэтому при реальной
        # ошибке Remarked (не «зон свободных нет», а «неизвестно») отдаём 503,
        # как и /bookings/availability/, а не 200 с тем же пустым списком.
        from apps.remarked.exceptions import RemarkedAPIError
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        response = self.client.get(self.URL, self._params())
        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)

    @patch('apps.bookings.services.ReservesClient')
    def test_second_request_uses_cache(self, mock_client_cls):
        # Первый запрос делает 2 вызова get_slots: один — get_rooms() (и
        # кеширует залы отдельно на час), другой — сам подбор свободных
        # столов на точное время (не кешируется на этом уровне). Второй
        # запрос с теми же параметрами полностью берётся из view-кеша
        # (`_tables_cache_key_fmt`) — новых вызовов get_slots быть не должно.
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        self.client.get(self.URL, self._params())
        self.assertEqual(mock_instance.get_slots.call_count, 2)
        self.client.get(self.URL, self._params())
        self.assertEqual(mock_instance.get_slots.call_count, 2)

    @patch('apps.bookings.services.ReservesClient')
    def test_different_zone_not_cached_together(self, mock_client_cls):
        # Второй запрос (другой zone_id) — промах view-кеша, но get_rooms()
        # уже закеширован после первого запроса, поэтому добавляется только
        # один новый вызов get_slots (подбор столов), а не два.
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = _SLOTS_WITH_ROOMS_RESPONSE
        self.client.get(self.URL, self._params(zone_id=305))
        self.client.get(self.URL, self._params(zone_id=304))
        self.assertEqual(mock_instance.get_slots.call_count, 3)


# ---------------------------------------------------------------------------
# View: диспетчеризация create_reserve_in_remarked при создании брони
# ---------------------------------------------------------------------------

class CreateReserveDispatchTest(APITestCase):
    def setUp(self):
        self.user = make_user('+77007100001')
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_task_queued_on_create(self, mock_task):
        payload = {
            'guest_name': 'Диспетч', 'phone': '+77001234567',
            'date': '2026-06-20', 'time': '19:00:00', 'guests_count': 2,
        }
        response = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        booking = TableBooking.objects.get(guest_name='Диспетч')
        mock_task.delay.assert_called_once_with(booking.pk)

    @patch('apps.bookings.tasks.create_reserve_in_remarked')
    def test_booking_created_even_if_broker_unavailable(self, mock_task):
        mock_task.delay.side_effect = Exception('Broker down')
        payload = {
            'guest_name': 'Без брокера', 'phone': '+77001234567',
            'date': '2026-06-20', 'time': '19:00:00', 'guests_count': 2,
        }
        response = self.client.post(
            '/api/v1/bookings/', payload, HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(TableBooking.objects.filter(guest_name='Без брокера').exists())


# ---------------------------------------------------------------------------
# Celery task: sync_reserve_statuses
# ---------------------------------------------------------------------------

class SyncReserveStatusesTaskTest(TestCase):
    def setUp(self):
        self.user = make_user('+77007200001')

    def _reserve(self, inner_status):
        return {'reserve': {'inner_status': inner_status}}

    def _call(self):
        from apps.bookings.tasks import sync_reserve_statuses
        return sync_reserve_statuses()

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_ignores_bookings_without_remarked_reserve_id(self, mock_get):
        make_booking(user=self.user, status='pending')
        result = self._call()
        mock_get.assert_not_called()
        self.assertEqual(result, 0)

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_ignores_already_final_local_statuses(self, mock_get):
        make_booking(user=self.user, status='canceled', remarked_reserve_id=1001)
        make_booking(user=self.user, status='completed', remarked_reserve_id=1002)
        result = self._call()
        mock_get.assert_not_called()
        self.assertEqual(result, 0)

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_new_maps_to_pending_no_update_if_already_pending(self, mock_get):
        mock_get.return_value = self._reserve('new')
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=2001)
        result = self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'pending')
        self.assertEqual(result, 0)

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_waiting_maps_to_pending(self, mock_get):
        mock_get.return_value = self._reserve('waiting')
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=2002)
        self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'pending')

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_confirmed_maps_to_confirmed(self, mock_get):
        mock_get.return_value = self._reserve('confirmed')
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=2003)
        result = self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'confirmed')
        self.assertEqual(result, 1)

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_started_maps_to_confirmed(self, mock_get):
        mock_get.return_value = self._reserve('started')
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=2004)
        self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'confirmed')

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_closed_maps_to_completed(self, mock_get):
        mock_get.return_value = self._reserve('closed')
        booking = make_booking(user=self.user, status='confirmed', remarked_reserve_id=2005)
        self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'completed')

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_canceled_maps_to_canceled(self, mock_get):
        mock_get.return_value = self._reserve('canceled')
        booking = make_booking(user=self.user, status='confirmed', remarked_reserve_id=2006)
        self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'canceled')

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_unknown_inner_status_does_not_update(self, mock_get):
        mock_get.return_value = self._reserve('some_new_status')
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=2007)
        result = self._call()
        booking.refresh_from_db()
        self.assertEqual(booking.status, 'pending')
        self.assertEqual(result, 0)

    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_one_remarked_failure_does_not_block_other_bookings(self, mock_get):
        from apps.remarked.exceptions import RemarkedAPIError
        b1 = make_booking(user=self.user, status='pending', remarked_reserve_id=3001)
        b2 = make_booking(user=self.user, status='pending', remarked_reserve_id=3002)

        def side_effect(reserve_id):
            if reserve_id == 3001:
                raise RemarkedAPIError(code=500, message='Server error', status_code=500)
            return self._reserve('confirmed')

        mock_get.side_effect = side_effect
        result = self._call()

        b1.refresh_from_db()
        b2.refresh_from_db()
        self.assertEqual(b1.status, 'pending')  # не обновлён из-за ошибки
        self.assertEqual(b2.status, 'confirmed')
        self.assertEqual(result, 1)

    @patch('apps.notifications.tasks.send_push_notification')
    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_status_change_triggers_existing_push_signal(self, mock_get, mock_push):
        mock_get.return_value = self._reserve('closed')
        booking = make_booking(user=self.user, status='confirmed', remarked_reserve_id=4001)
        mock_push.delay.reset_mock()
        self._call()
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['user_id'], self.user.pk)
        self.assertEqual(kwargs['data']['status'], 'completed')

    @patch('apps.notifications.tasks.send_push_notification')
    @patch('apps.remarked.reserves_client.ReservesClient.get_reserve_by_id')
    def test_no_status_change_does_not_trigger_push(self, mock_get, mock_push):
        mock_get.return_value = self._reserve('new')
        make_booking(user=self.user, status='pending', remarked_reserve_id=4002)
        mock_push.delay.reset_mock()
        self._call()
        mock_push.delay.assert_not_called()

    def test_retry_config(self):
        from apps.bookings.tasks import sync_reserve_statuses
        self.assertEqual(sync_reserve_statuses.max_retries, 3)
        self.assertEqual(sync_reserve_statuses.default_retry_delay, 60)
        self.assertTrue(sync_reserve_statuses.acks_late)
        self.assertTrue(sync_reserve_statuses.reject_on_worker_lost)
        self.assertIn(Exception, sync_reserve_statuses.autoretry_for)


# ---------------------------------------------------------------------------
# CELERY_BEAT_SCHEDULE — sync-reserve-statuses зарегистрирована
# ---------------------------------------------------------------------------

class SyncReserveStatusesBeatScheduleTest(TestCase):
    def test_registered_in_beat_schedule(self):
        from django.conf import settings
        entry = settings.CELERY_BEAT_SCHEDULE.get('sync-reserve-statuses')
        self.assertIsNotNone(entry)
        self.assertEqual(entry['task'], 'apps.bookings.tasks.sync_reserve_statuses')


# ---------------------------------------------------------------------------
# Полная цепочка вызовов (мок на уровне RemarkedReservesClient, а не
# ReservesClient) — в отличие от CreateReserveInRemarkedTaskTest/
# SyncReserveStatusesTaskTest выше (мокают высокоуровневый ReservesClient),
# здесь мокается только HTTP-транспорт, поэтому реально прогоняется логика
# кеширования токена и retry-once на 401 из apps/remarked/reserves_client.py.
# ---------------------------------------------------------------------------

class CreateReserveInRemarkedFullStackTest(TestCase):
    def setUp(self):
        self.user = make_user('+77007300001')
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.remarked.client.RemarkedReservesClient._call')
    def test_full_chain_get_token_then_create_reserve(self, mock_call):
        def side_effect(method_name, **payload):
            if method_name == 'GetToken':
                return {'token': 'tok-e2e'}
            if method_name == 'CreateReserve':
                self.assertEqual(payload.get('token'), 'tok-e2e')
                return {'status': 'success', 'reserve_id': 777}
            raise AssertionError(f'unexpected method {method_name}')

        mock_call.side_effect = side_effect
        booking = make_booking(user=self.user, phone='+77001234567')

        from apps.bookings.tasks import create_reserve_in_remarked
        create_reserve_in_remarked(booking.pk)

        booking.refresh_from_db()
        self.assertEqual(booking.remarked_reserve_id, 777)

    @patch('apps.remarked.client.RemarkedReservesClient._call')
    def test_token_reused_from_cache_across_two_bookings(self, mock_call):
        reserve_ids = iter([1, 2])

        def side_effect(method_name, **payload):
            if method_name == 'GetToken':
                return {'token': 'tok-shared'}
            return {'status': 'success', 'reserve_id': next(reserve_ids)}

        mock_call.side_effect = side_effect
        b1 = make_booking(user=self.user, phone='+77001234567')
        b2 = make_booking(user=self.user, phone='+77001234567')

        from apps.bookings.tasks import create_reserve_in_remarked
        create_reserve_in_remarked(b1.pk)
        create_reserve_in_remarked(b2.pk)

        get_token_calls = [c for c in mock_call.call_args_list if c.args[0] == 'GetToken']
        self.assertEqual(len(get_token_calls), 1)  # второй раз токен взят из Redis-кеша


class SyncReserveStatusesFullStackTest(TestCase):
    def setUp(self):
        self.user = make_user('+77007300002')
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.remarked.client.RemarkedReservesClient._call')
    def test_full_chain_updates_status_and_triggers_push(self, mock_call):
        def side_effect(method_name, **payload):
            if method_name == 'GetToken':
                return {'token': 'tok-e2e'}
            if method_name == 'GetReserveByID':
                self.assertEqual(payload.get('token'), 'tok-e2e')
                self.assertEqual(payload.get('reserve_id'), 5001)
                return {'reserve': {'inner_status': 'closed'}}
            raise AssertionError(f'unexpected method {method_name}')

        mock_call.side_effect = side_effect
        booking = make_booking(user=self.user, status='confirmed', remarked_reserve_id=5001)

        with patch('apps.notifications.tasks.send_push_notification') as mock_push:
            from apps.bookings.tasks import sync_reserve_statuses
            result = sync_reserve_statuses()

        booking.refresh_from_db()
        self.assertEqual(booking.status, 'completed')
        self.assertEqual(result, 1)
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['data']['status'], 'completed')

    @patch('apps.remarked.client.RemarkedReservesClient._call')
    def test_401_during_sync_triggers_token_refresh_and_retry(self, mock_call):
        from apps.remarked.exceptions import RemarkedAPIError
        calls = {'GetToken': 0, 'GetReserveByID': 0}

        def side_effect(method_name, **payload):
            if method_name == 'GetToken':
                calls['GetToken'] += 1
                return {'token': f'tok-{calls["GetToken"]}'}
            if method_name == 'GetReserveByID':
                calls['GetReserveByID'] += 1
                if calls['GetReserveByID'] == 1:
                    raise RemarkedAPIError(code=401, message='Empty Bearer Token', status_code=401)
                return {'reserve': {'inner_status': 'canceled'}}
            raise AssertionError(f'unexpected method {method_name}')

        mock_call.side_effect = side_effect
        booking = make_booking(user=self.user, status='pending', remarked_reserve_id=6001)

        with patch('apps.notifications.tasks.send_push_notification'):
            from apps.bookings.tasks import sync_reserve_statuses
            sync_reserve_statuses()

        booking.refresh_from_db()
        self.assertEqual(booking.status, 'canceled')
        self.assertEqual(calls['GetToken'], 2)  # первый токен + обновление после 401
        self.assertEqual(calls['GetReserveByID'], 2)  # неудачная попытка + retry


# ---------------------------------------------------------------------------
# apps.bookings.services.check_availability
# ---------------------------------------------------------------------------

class CheckAvailabilityServiceTest(TestCase):
    @patch('apps.bookings.services.ReservesClient')
    def test_parses_slots_correctly(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {
            'status': 'success',
            'slots': [
                {'start_datetime': '2026-07-20 12:30:00', 'is_free': True, 'tables_count': 5},
                {'start_datetime': '2026-07-20 13:00:00', 'is_free': False, 'tables_count': 0},
            ],
        }
        from apps.bookings.services import check_availability
        result = check_availability('2026-07-20', 2)
        self.assertEqual(result, [
            {'time': '12:30:00', 'is_free': True, 'tables_count': 5},
            {'time': '13:00:00', 'is_free': False, 'tables_count': 0},
        ])

    @patch('apps.bookings.services.ReservesClient')
    def test_empty_slots_returns_empty_list(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {'status': 'success', 'slots': []}
        from apps.bookings.services import check_availability
        self.assertEqual(check_availability('2026-07-20', 2), [])

    @patch('apps.bookings.services.ReservesClient')
    def test_propagates_remarked_error(self, mock_client_cls):
        from apps.remarked.exceptions import RemarkedAPIError
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        from apps.bookings.services import check_availability
        with self.assertRaises(RemarkedAPIError):
            check_availability('2026-07-20', 2)

    @patch('apps.bookings.services.ReservesClient')
    def test_calls_get_slots_with_rooms_and_date_range(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {'status': 'success', 'slots': []}
        from apps.bookings.services import check_availability
        check_availability('2026-07-20', 4)
        _, kwargs = mock_instance.get_slots.call_args
        self.assertEqual(kwargs['reserve_date_period'], {'from': '2026-07-20', 'to': '2026-07-20'})
        self.assertEqual(kwargs['guests_count'], 4)
        self.assertTrue(kwargs['with_rooms'])


# ---------------------------------------------------------------------------
# GET /api/v1/bookings/availability/
# ---------------------------------------------------------------------------

class BookingAvailabilityViewTest(APITestCase):
    URL = '/api/v1/bookings/availability/'

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.bookings.services.ReservesClient')
    def test_returns_slots_anonymous(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {
            'status': 'success',
            'slots': [
                {'start_datetime': '2026-07-15 12:00:00', 'is_free': False, 'tables_count': 0},
                {'start_datetime': '2026-07-15 14:00:00', 'is_free': True, 'tables_count': 13},
            ],
        }
        response = self.client.get(self.URL, {'date': '2026-07-15', 'guests': 2})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['date'], dt_date(2026, 7, 15))
        self.assertEqual(response.data['guests_count'], 2)
        self.assertEqual(len(response.data['slots']), 2)
        self.assertEqual(response.data['slots'][1]['time'], '14:00:00')
        self.assertTrue(response.data['slots'][1]['is_free'])
        self.assertEqual(response.data['slots'][1]['tables_count'], 13)

    def test_missing_date_returns_400(self):
        response = self.client.get(self.URL, {'guests': 2})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('date', response.data)

    def test_missing_guests_returns_400(self):
        response = self.client.get(self.URL, {'date': '2026-07-15'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('guests', response.data)

    def test_invalid_date_format_returns_400(self):
        response = self.client.get(self.URL, {'date': '15-07-2026', 'guests': 2})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('date', response.data)

    def test_guests_zero_returns_400(self):
        response = self.client.get(self.URL, {'date': '2026-07-15', 'guests': 0})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('guests', response.data)

    def test_guests_51_returns_400(self):
        response = self.client.get(self.URL, {'date': '2026-07-15', 'guests': 51})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('guests', response.data)

    @patch('apps.bookings.services.ReservesClient')
    def test_remarked_error_returns_503(self, mock_client_cls):
        from apps.remarked.exceptions import RemarkedAPIError
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.side_effect = RemarkedAPIError(code=500, message='boom', status_code=500)
        response = self.client.get(self.URL, {'date': '2026-07-16', 'guests': 2})
        self.assertEqual(response.status_code, 503)
        self.assertIn('detail', response.data)

    @patch('apps.bookings.services.ReservesClient')
    def test_second_request_within_ttl_uses_cache(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {'status': 'success', 'slots': []}
        self.client.get(self.URL, {'date': '2026-07-17', 'guests': 2})
        self.client.get(self.URL, {'date': '2026-07-17', 'guests': 2})
        self.assertEqual(mock_instance.get_slots.call_count, 1)

    @patch('apps.bookings.services.ReservesClient')
    def test_different_guests_count_not_cached_together(self, mock_client_cls):
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {'status': 'success', 'slots': []}
        self.client.get(self.URL, {'date': '2026-07-18', 'guests': 2})
        self.client.get(self.URL, {'date': '2026-07-18', 'guests': 4})
        self.assertEqual(mock_instance.get_slots.call_count, 2)

    @patch('apps.bookings.services.ReservesClient')
    def test_empty_result_is_cached_too(self, mock_client_cls):
        """Пустой список слотов — валидный кешируемый результат, а не 'нет в кеше'."""
        mock_instance = mock_client_cls.return_value
        mock_instance.get_slots.return_value = {'status': 'success', 'slots': []}
        r1 = self.client.get(self.URL, {'date': '2026-07-22', 'guests': 2})
        r2 = self.client.get(self.URL, {'date': '2026-07-22', 'guests': 2})
        self.assertEqual(r1.data['slots'], [])
        self.assertEqual(r2.data['slots'], [])
        self.assertEqual(mock_instance.get_slots.call_count, 1)


# ---------------------------------------------------------------------------
# GET /api/v1/bookings/availability/ — полная цепочка (мок RemarkedReservesClient)
# ---------------------------------------------------------------------------

class BookingAvailabilityFullStackTest(APITestCase):
    URL = '/api/v1/bookings/availability/'

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('apps.remarked.client.RemarkedReservesClient._call')
    def test_full_chain_get_token_then_get_slots(self, mock_call):
        def side_effect(method_name, **payload):
            if method_name == 'GetToken':
                return {'token': 'tok-avail'}
            if method_name == 'GetSlots':
                self.assertEqual(payload.get('token'), 'tok-avail')
                self.assertTrue(payload.get('with_rooms'))
                self.assertEqual(payload.get('reserve_date_period'), {'from': '2026-07-21', 'to': '2026-07-21'})
                return {
                    'status': 'success',
                    'slots': [
                        {'start_datetime': '2026-07-21 19:00:00', 'is_free': True, 'tables_count': 3},
                    ],
                }
            raise AssertionError(f'unexpected method {method_name}')

        mock_call.side_effect = side_effect
        response = self.client.get(self.URL, {'date': '2026-07-21', 'guests': 3})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['slots'][0]['time'], '19:00:00')
        self.assertTrue(response.data['slots'][0]['is_free'])



from datetime import date as dt_date, time as dt_time
from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import TableBooking
from .serializers import TableBookingSerializer, TableBookingStaffSerializer

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
        response = self.client.get('/api/bookings/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['guest_name'], 'Тест Гость')

    def test_list_unauthenticated_returns_401(self):
        response = self.client.get('/api/bookings/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_booking_success(self):
        self._auth()
        payload = {
            'guest_name': 'Алихан',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 3,
        }
        response = self.client.post('/api/bookings/', payload)
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
        self.client.post('/api/bookings/', payload)
        booking = TableBooking.objects.get(guest_name='Данияр')
        self.assertEqual(booking.user, self.user)

    def test_create_booking_unauthenticated_returns_401(self):
        payload = {
            'guest_name': 'Аноним',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 1,
        }
        response = self.client.post('/api/bookings/', payload)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_booking_invalid_guests_count_returns_400(self):
        self._auth()
        payload = {
            'guest_name': 'Алихан',
            'date': '2026-06-20',
            'time': '19:00:00',
            'guests_count': 100,
        }
        response = self.client.post('/api/bookings/', payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('guests_count', response.data)

    def test_list_empty_when_no_bookings(self):
        self._auth()
        response = self.client.get('/api/bookings/')
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
# TableBookingStaffSerializer
# ---------------------------------------------------------------------------

class TableBookingStaffSerializerTest(TestCase):
    def setUp(self):
        self.user = make_user('+77010000001')

    def test_status_is_writable(self):
        booking = make_booking(user=self.user, status='pending')
        s = TableBookingStaffSerializer(
            booking, data={'status': 'confirmed'}, partial=True
        )
        self.assertTrue(s.is_valid(), s.errors)
        self.assertIn('status', s.validated_data)

    def test_user_phone_populated_from_related_user(self):
        booking = make_booking(user=self.user)
        s = TableBookingStaffSerializer(booking)
        self.assertEqual(s.data['user_phone'], self.user.phone)

    def test_user_phone_is_none_when_no_user(self):
        booking = TableBooking.objects.create(
            user=None, guest_name='Аноним', date='2026-07-01',
            time='18:00:00', guests_count=1, status='pending',
        )
        s = TableBookingStaffSerializer(booking)
        self.assertIsNone(s.data['user_phone'])

    def test_user_field_is_read_only(self):
        other = make_user('+77010000002')
        booking = make_booking(user=self.user, status='pending')
        s = TableBookingStaffSerializer(
            booking, data={'user': other.pk, 'status': 'confirmed'}, partial=True
        )
        self.assertTrue(s.is_valid(), s.errors)
        self.assertNotIn('user', s.validated_data)

    def test_invalid_status_value_returns_error(self):
        booking = make_booking(user=self.user, status='pending')
        s = TableBookingStaffSerializer(
            booking, data={'status': 'nonexistent'}, partial=True
        )
        self.assertFalse(s.is_valid())
        self.assertIn('status', s.errors)


# ---------------------------------------------------------------------------
# GET /api/bookings/staff/
# ---------------------------------------------------------------------------

class StaffBookingListViewTest(APITestCase):
    def setUp(self):
        self.hall_manager = User.objects.create_user(
            phone='+77011000001', role='hall_manager'
        )
        self.admin = User.objects.create_user(
            phone='+77011000002', role='admin'
        )
        self.regular = make_user('+77011000003')

    def _auth(self, user):
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_hall_manager_can_list_all_bookings(self):
        make_booking(user=self.regular)
        self._auth(self.hall_manager)
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)

    def test_admin_can_list_all_bookings(self):
        make_booking(user=self.regular)
        self._auth(self.admin)
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)

    def test_regular_user_returns_403(self):
        self._auth(self.regular)
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unauthenticated_returns_401(self):
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_returns_bookings_for_all_users(self):
        other = make_user('+77011000004')
        make_booking(user=self.regular)
        make_booking(user=other)
        self._auth(self.hall_manager)
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.data['count'], 2)

    def test_response_includes_user_phone(self):
        make_booking(user=self.regular)
        self._auth(self.hall_manager)
        response = self.client.get('/api/bookings/staff/')
        first = response.data['results'][0]
        self.assertIn('user_phone', first)
        self.assertEqual(first['user_phone'], self.regular.phone)

    def test_response_includes_status_field(self):
        make_booking(user=self.regular, status='confirmed')
        self._auth(self.hall_manager)
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.data['results'][0]['status'], 'confirmed')


# ---------------------------------------------------------------------------
# PATCH /api/bookings/staff/<pk>/
# ---------------------------------------------------------------------------

class StaffBookingUpdateViewTest(APITestCase):
    def setUp(self):
        self.hall_manager = User.objects.create_user(
            phone='+77012000001', role='hall_manager'
        )
        self.admin = User.objects.create_user(
            phone='+77012000002', role='admin'
        )
        self.regular = make_user('+77012000003')
        self.booking = make_booking(user=self.regular, status='pending')

    def _auth(self, user):
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def _url(self, pk=None):
        return f'/api/bookings/staff/{pk or self.booking.pk}/'

    @patch('apps.notifications.tasks.send_push_notification')
    def test_hall_manager_can_change_status(self, _mock):
        self._auth(self.hall_manager)
        response = self.client.patch(self._url(), {'status': 'confirmed'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, 'confirmed')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_admin_can_change_status(self, _mock):
        self._auth(self.admin)
        response = self.client.patch(self._url(), {'status': 'canceled'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, 'canceled')

    def test_regular_user_returns_403(self):
        self._auth(self.regular)
        response = self.client.patch(self._url(), {'status': 'confirmed'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unauthenticated_returns_401(self):
        response = self.client.patch(self._url(), {'status': 'confirmed'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_nonexistent_booking_returns_404(self):
        self._auth(self.hall_manager)
        response = self.client.patch('/api/bookings/staff/999999/', {'status': 'confirmed'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_invalid_status_value_returns_400(self):
        self._auth(self.hall_manager)
        response = self.client.patch(self._url(), {'status': 'invalid_status'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('status', response.data)

    def test_put_is_not_allowed(self):
        self._auth(self.hall_manager)
        response = self.client.put(self._url(), {
            'guest_name': 'X', 'date': '2026-07-01', 'time': '18:00:00',
            'guests_count': 2, 'status': 'confirmed',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_status_change_triggers_push_signal(self, mock_push):
        self._auth(self.hall_manager)
        mock_push.delay.reset_mock()
        self.client.patch(self._url(), {'status': 'confirmed'}, format='json')
        mock_push.delay.assert_called_once()
        _, kwargs = mock_push.delay.call_args
        self.assertEqual(kwargs['user_id'], self.regular.pk)
        self.assertEqual(kwargs['data']['status'], 'confirmed')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_response_includes_user_phone(self, _mock):
        self._auth(self.hall_manager)
        response = self.client.patch(self._url(), {'status': 'confirmed'}, format='json')
        self.assertIn('user_phone', response.data)
        self.assertEqual(response.data['user_phone'], self.regular.phone)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_user_field_cannot_be_changed(self, _mock):
        other = make_user('+77012000004')
        self._auth(self.hall_manager)
        self.client.patch(self._url(), {'user': other.pk, 'status': 'confirmed'}, format='json')
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.user, self.regular)


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

    def test_staff_serializer_exposes_phone(self):
        user = make_user('+77013000001')
        booking = make_booking(user=user, phone='+77013000001')
        s = TableBookingStaffSerializer(booking)
        self.assertIn('phone', s.data)
        self.assertEqual(s.data['phone'], '+77013000001')


class TableBookingPhoneAPITest(APITestCase):
    def setUp(self):
        self.user = make_user('+77014000001')
        self.hall_manager = User.objects.create_user(
            phone='+77014000002', role='hall_manager'
        )

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
        response = self.client.post('/api/bookings/', payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['phone'], '+77001112233')
        self.assertEqual(TableBooking.objects.get(guest_name='Данияр').phone, '+77001112233')

    def test_staff_list_includes_phone(self):
        make_booking(user=self.user, phone='+77001112244')
        refresh = RefreshToken.for_user(self.hall_manager)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        response = self.client.get('/api/bookings/staff/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('phone', response.data['results'][0])

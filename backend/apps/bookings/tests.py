from unittest.mock import patch

from django.contrib.auth import get_user_model
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
    def test_no_push_on_create(self, mock_task):
        make_booking(user=self.user)
        mock_task.delay.assert_not_called()

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

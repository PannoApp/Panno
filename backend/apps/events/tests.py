from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase, APIRequestFactory
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Event, News, EventReservation
from .serializers import EventReservationSerializer, EventReservationStaffSerializer

User = get_user_model()

# Minimal 1×1 PNG for ImageField
_PNG = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01'
    b'\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00'
    b'\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18'
    b'\xd8N\x00\x00\x00\x00IEND\xaeB`\x82'
)


def make_image(name='img.png'):
    return SimpleUploadedFile(name, _PNG, content_type='image/png')


def make_event(title='Тест', days_offset=1, is_active=True):
    dt = timezone.now() + timezone.timedelta(days=days_offset)
    return Event.objects.create(
        title=title,
        description='Описание',
        date_time=dt,
        image=make_image(),
        is_active=is_active,
    )


def make_past_event(title='Архив'):
    dt = timezone.now() - timezone.timedelta(days=1)
    return Event.objects.create(
        title=title,
        description='Прошедшее',
        date_time=dt,
        image=make_image(),
        is_active=True,
    )


def make_user(phone='+77001234567'):
    return User.objects.create_user(phone=phone)


# ---------------------------------------------------------------------------
# GET /api/events/upcoming/
# ---------------------------------------------------------------------------

class UpcomingEventsListViewTest(APITestCase):
    def test_returns_upcoming_active_events(self):
        make_event(title='Будущее', days_offset=2)
        make_past_event(title='Прошлое')
        response = self.client.get('/api/events/upcoming/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Будущее', titles)
        self.assertNotIn('Прошлое', titles)

    def test_excludes_inactive_events(self):
        make_event(title='Активное', days_offset=1, is_active=True)
        make_event(title='Неактивное', days_offset=2, is_active=False)
        response = self.client.get('/api/events/upcoming/')
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Активное', titles)
        self.assertNotIn('Неактивное', titles)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/events/upcoming/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_sorted_by_nearest_first(self):
        make_event(title='Далёкое', days_offset=10)
        make_event(title='Ближнее', days_offset=2)
        response = self.client.get('/api/events/upcoming/')
        titles = [e['title'] for e in response.data['results']]
        self.assertLess(titles.index('Ближнее'), titles.index('Далёкое'))


# ---------------------------------------------------------------------------
# GET /api/events/archived/
# ---------------------------------------------------------------------------

class ArchivedEventsListViewTest(APITestCase):
    def test_returns_past_events_only(self):
        make_past_event(title='Прошедшее')
        make_event(title='Будущее', days_offset=1)
        response = self.client.get('/api/events/archived/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Прошедшее', titles)
        self.assertNotIn('Будущее', titles)

    def test_excludes_inactive_past_events(self):
        dt = timezone.now() - timezone.timedelta(days=1)
        Event.objects.create(
            title='НеактивноеПрошлое',
            description='x',
            date_time=dt,
            image=make_image(),
            is_active=False,
        )
        response = self.client.get('/api/events/archived/')
        titles = [e['title'] for e in response.data['results']]
        self.assertNotIn('НеактивноеПрошлое', titles)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/events/archived/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# GET /api/events/news/
# ---------------------------------------------------------------------------

class NewsListViewTest(APITestCase):
    def test_returns_news_newest_first(self):
        News.objects.create(title='Старая', content='...')
        News.objects.create(title='Свежая', content='...')
        response = self.client.get('/api/events/news/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [n['title'] for n in response.data['results']]
        self.assertIn('Свежая', titles)
        self.assertLess(titles.index('Свежая'), titles.index('Старая'))

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/events/news/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_empty_list_returns_200(self):
        response = self.client.get('/api/events/news/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 0)


# ---------------------------------------------------------------------------
# POST /api/events/reservations/create/
# ---------------------------------------------------------------------------

class EventReservationCreateViewTest(APITestCase):
    def setUp(self):
        self.user = make_user('+77001111111')
        self.event = make_event()

    def _auth(self, user=None):
        refresh = RefreshToken.for_user(user or self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    @patch('apps.notifications.tasks.send_push_notification')
    def test_create_reservation_success(self, _):
        self._auth()
        response = self.client.post('/api/events/reservations/create/', {
            'event': self.event.pk,
            'guests_count': 2,
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['event'], self.event.pk)
        self.assertEqual(response.data['guests_count'], 2)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_create_sets_user_from_token(self, _):
        self._auth()
        self.client.post('/api/events/reservations/create/', {'event': self.event.pk})
        reservation = EventReservation.objects.get(event=self.event, user=self.user)
        self.assertEqual(reservation.user, self.user)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_duplicate_reservation_returns_400(self, _):
        self._auth()
        self.client.post('/api/events/reservations/create/', {'event': self.event.pk})
        response = self.client.post('/api/events/reservations/create/', {'event': self.event.pk})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('non_field_errors', response.data)

    def test_unauthenticated_returns_401(self):
        response = self.client.post('/api/events/reservations/create/', {
            'event': self.event.pk,
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_invalid_event_id_returns_400(self, _):
        self._auth()
        response = self.client.post('/api/events/reservations/create/', {'event': 99999})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


# ---------------------------------------------------------------------------
# GET /api/events/reservations/my/
# ---------------------------------------------------------------------------

class UserEventReservationsListViewTest(APITestCase):
    def setUp(self):
        self.user = make_user('+77001111111')
        self.other = make_user('+77002222222')
        self.event = make_event()

    def _auth(self, user=None):
        refresh = RefreshToken.for_user(user or self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_returns_only_own_reservations(self):
        EventReservation.objects.create(event=self.event, user=self.user)
        EventReservation.objects.create(event=self.event, user=self.other)
        self._auth()
        response = self.client.get('/api/events/reservations/my/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)

    def test_unauthenticated_returns_401(self):
        response = self.client.get('/api/events/reservations/my/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_response_contains_event_details(self):
        EventReservation.objects.create(event=self.event, user=self.user)
        self._auth()
        response = self.client.get('/api/events/reservations/my/')
        result = response.data['results'][0]
        self.assertIn('event_details', result)
        self.assertEqual(result['event_details']['id'], self.event.pk)


# ---------------------------------------------------------------------------
# EventReservationSerializer validation
# ---------------------------------------------------------------------------

class EventReservationSerializerTest(TestCase):
    def setUp(self):
        self.user = make_user('+77009999999')
        self.event = make_event()

    def _context(self):
        factory = APIRequestFactory()
        request = factory.post('/')
        request.user = self.user
        return {'request': request}

    def test_first_reservation_is_valid(self):
        s = EventReservationSerializer(
            data={'event': self.event.pk},
            context=self._context(),
        )
        self.assertTrue(s.is_valid(), s.errors)

    def test_duplicate_raises_validation_error(self):
        EventReservation.objects.create(event=self.event, user=self.user)
        s = EventReservationSerializer(
            data={'event': self.event.pk},
            context=self._context(),
        )
        self.assertFalse(s.is_valid())
        self.assertIn('non_field_errors', s.errors)


# ---------------------------------------------------------------------------
# Signal: notify_on_reservation_created
# ---------------------------------------------------------------------------

class EventReservationSignalTest(TestCase):
    def setUp(self):
        self.user = make_user('+77005555555')
        self.event = make_event()

    @patch('apps.notifications.tasks.send_push_notification')
    def test_push_sent_on_reservation_create(self, mock_task):
        EventReservation.objects.create(event=self.event, user=self.user)
        mock_task.delay.assert_called_once()
        _, kwargs = mock_task.delay.call_args
        self.assertEqual(kwargs['user_id'], self.user.pk)
        self.assertEqual(kwargs['data']['event_id'], str(self.event.pk))

    @patch('apps.notifications.tasks.send_push_notification')
    def test_no_push_on_reservation_update(self, mock_task):
        reservation = EventReservation.objects.create(event=self.event, user=self.user)
        mock_task.delay.reset_mock()
        reservation.guests_count = 5
        reservation.save()
        mock_task.delay.assert_not_called()


# ---------------------------------------------------------------------------
# EventReservationStaffSerializer
# ---------------------------------------------------------------------------

class EventReservationStaffSerializerTest(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            phone='+77030000001', first_name='Алихан', last_name='Сейткали'
        )
        self.event = make_event()

    def test_staff_serializer_includes_guest_name(self):
        reservation = EventReservation.objects.create(event=self.event, user=self.user)
        s = EventReservationStaffSerializer(reservation)
        self.assertIn('guest_name', s.data)
        self.assertEqual(s.data['guest_name'], 'Алихан Сейткали')

    def test_staff_serializer_includes_guest_phone(self):
        reservation = EventReservation.objects.create(event=self.event, user=self.user)
        s = EventReservationStaffSerializer(reservation)
        self.assertIn('guest_phone', s.data)
        self.assertEqual(s.data['guest_phone'], '+77030000001')

    def test_guest_name_falls_back_to_phone_if_no_name(self):
        User = get_user_model()
        user_no_name = User.objects.create_user(phone='+77030000002')
        reservation = EventReservation.objects.create(event=self.event, user=user_no_name)
        s = EventReservationStaffSerializer(reservation)
        self.assertEqual(s.data['guest_name'], '+77030000002')

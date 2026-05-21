import uuid
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase, APIRequestFactory
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Event, News, EventReservation, EventPhotoReport
from .serializers import EventReservationSerializer, EventReservationStaffSerializer, EventSerializer

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
        response = self.client.get('/api/v1/events/upcoming/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Будущее', titles)
        self.assertNotIn('Прошлое', titles)

    def test_excludes_inactive_events(self):
        make_event(title='Активное', days_offset=1, is_active=True)
        make_event(title='Неактивное', days_offset=2, is_active=False)
        response = self.client.get('/api/v1/events/upcoming/')
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Активное', titles)
        self.assertNotIn('Неактивное', titles)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/events/upcoming/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_sorted_by_nearest_first(self):
        make_event(title='Далёкое', days_offset=10)
        make_event(title='Ближнее', days_offset=2)
        response = self.client.get('/api/v1/events/upcoming/')
        titles = [e['title'] for e in response.data['results']]
        self.assertLess(titles.index('Ближнее'), titles.index('Далёкое'))


# ---------------------------------------------------------------------------
# GET /api/events/archived/
# ---------------------------------------------------------------------------

class ArchivedEventsListViewTest(APITestCase):
    def test_returns_past_events_only(self):
        make_past_event(title='Прошедшее')
        make_event(title='Будущее', days_offset=1)
        response = self.client.get('/api/v1/events/archived/')
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
        response = self.client.get('/api/v1/events/archived/')
        titles = [e['title'] for e in response.data['results']]
        self.assertNotIn('НеактивноеПрошлое', titles)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/events/archived/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# GET /api/events/news/
# ---------------------------------------------------------------------------

class NewsListViewTest(APITestCase):
    def test_returns_news_newest_first(self):
        News.objects.create(title='Старая', content='...')
        News.objects.create(title='Свежая', content='...')
        response = self.client.get('/api/v1/events/news/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [n['title'] for n in response.data['results']]
        self.assertIn('Свежая', titles)
        self.assertLess(titles.index('Свежая'), titles.index('Старая'))

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/events/news/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_empty_list_returns_200(self):
        response = self.client.get('/api/v1/events/news/')
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
        response = self.client.post(
            '/api/v1/events/reservations/create/',
            {'event': self.event.pk, 'guests_count': 2},
            HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['event'], self.event.pk)
        self.assertEqual(response.data['guests_count'], 2)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_create_sets_user_from_token(self, _):
        self._auth()
        self.client.post(
            '/api/v1/events/reservations/create/',
            {'event': self.event.pk},
            HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        reservation = EventReservation.objects.get(event=self.event, user=self.user)
        self.assertEqual(reservation.user, self.user)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_duplicate_reservation_returns_400(self, _):
        self._auth()
        # Two different idempotency keys so the second request reaches DB validation
        self.client.post(
            '/api/v1/events/reservations/create/',
            {'event': self.event.pk},
            HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        response = self.client.post(
            '/api/v1/events/reservations/create/',
            {'event': self.event.pk},
            HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('non_field_errors', response.data)

    def test_unauthenticated_returns_401(self):
        response = self.client.post('/api/v1/events/reservations/create/', {
            'event': self.event.pk,
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('apps.notifications.tasks.send_push_notification')
    def test_invalid_event_id_returns_400(self, _):
        self._auth()
        response = self.client.post(
            '/api/v1/events/reservations/create/',
            {'event': 99999},
            HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
        )
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
        response = self.client.get('/api/v1/events/reservations/my/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)

    def test_unauthenticated_returns_401(self):
        response = self.client.get('/api/v1/events/reservations/my/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_response_contains_event_details(self):
        EventReservation.objects.create(event=self.event, user=self.user)
        self._auth()
        response = self.client.get('/api/v1/events/reservations/my/')
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


# ---------------------------------------------------------------------------
# Idempotency — POST /api/v1/events/reservations/create/
# ---------------------------------------------------------------------------

class EventReservationIdempotencyTest(APITestCase):
    URL = '/api/v1/events/reservations/create/'

    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            phone='+77040000001',
            first_name='Идем',
            last_name='Потент',
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        self.event = make_event()
        self.payload = {'event': self.event.pk, 'guests_count': 1}
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_missing_key_returns_400(self):
        response = self.client.post(self.URL, self.payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Idempotency-Key', response.data['detail'])

    def test_invalid_key_returns_400(self):
        response = self.client.post(
            self.URL, self.payload, HTTP_IDEMPOTENCY_KEY='bad-key',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_first_request_creates_reservation(self):
        key = str(uuid.uuid4())
        response = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(EventReservation.objects.filter(user=self.user).count(), 1)

    def test_duplicate_key_does_not_create_second_reservation(self):
        key = str(uuid.uuid4())
        r1 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        r2 = self.client.post(self.URL, self.payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r1.data['id'], r2.data['id'])
        self.assertEqual(EventReservation.objects.filter(user=self.user).count(), 1)

    def test_validation_error_is_cached_and_returned_on_retry(self):
        key = str(uuid.uuid4())
        bad_payload = {'event': 99999, 'guests_count': 1}
        r1 = self.client.post(self.URL, bad_payload, HTTP_IDEMPOTENCY_KEY=key)
        r2 = self.client.post(self.URL, bad_payload, HTTP_IDEMPOTENCY_KEY=key)
        self.assertEqual(r1.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r2.status_code, status.HTTP_400_BAD_REQUEST)


# =============================================================================
# Кэширование: UpcomingEventsListView / ArchivedEventsListView / NewsListView
# =============================================================================

class EventsCacheTest(APITestCase):
    """Версионный кэш предстоящих и прошедших событий."""

    def setUp(self):
        cache.clear()
        make_event(title='Предстоящее 1', days_offset=1)
        make_event(title='Предстоящее 2', days_offset=2)
        make_past_event(title='Прошедшее 1')

    def tearDown(self):
        cache.clear()

    def _version(self, prefix):
        return cache.get(f'events_{prefix}_cache_version', 1)

    def test_upcoming_cache_hit_on_second_request(self):
        """Второй запрос к /upcoming/ попадает в кэш."""
        r1 = self.client.get('/api/v1/events/upcoming/')
        v  = self._version('upcoming')
        self.assertIsNotNone(cache.get(f'events_upcoming:{v}:'))
        r2 = self.client.get('/api/v1/events/upcoming/')
        self.assertEqual(r1.data, r2.data)

    def test_post_save_event_bumps_upcoming_version(self):
        """Сохранение Event инкрементирует версию кэша предстоящих событий."""
        self.client.get('/api/v1/events/upcoming/')
        v_before = self._version('upcoming')
        make_event(title='Новое', days_offset=5)
        self.assertGreater(self._version('upcoming'), v_before)

    def test_post_save_event_bumps_archived_version(self):
        """Сохранение Event инкрементирует версию кэша прошедших событий."""
        self.client.get('/api/v1/events/archived/')
        v_before = self._version('archived')
        make_past_event(title='Ещё одно прошлое')
        self.assertGreater(self._version('archived'), v_before)

    def test_after_invalidation_new_event_appears(self):
        """После инвалидации новое событие появляется в ответе."""
        self.client.get('/api/v1/events/upcoming/')
        make_event(title='Срочное мероприятие', days_offset=3)
        response = self.client.get('/api/v1/events/upcoming/')
        titles = [e['title'] for e in response.data['results']]
        self.assertIn('Срочное мероприятие', titles)


# ---------------------------------------------------------------------------
# EventPhotoReport — модель
# ---------------------------------------------------------------------------

class EventPhotoReportModelTest(TestCase):
    def test_str_contains_event_title(self):
        event = make_past_event(title='Джазовый вечер')
        photo = EventPhotoReport.objects.create(event=event, image=make_image())
        self.assertIn('Джазовый вечер', str(photo))

    def test_default_ordering_by_order_then_uploaded(self):
        event = make_past_event()
        EventPhotoReport.objects.create(event=event, image=make_image('a.png'), order=2)
        EventPhotoReport.objects.create(event=event, image=make_image('b.png'), order=0)
        EventPhotoReport.objects.create(event=event, image=make_image('c.png'), order=1)
        orders = list(EventPhotoReport.objects.filter(event=event).values_list('order', flat=True))
        self.assertEqual(orders, [0, 1, 2])


# ---------------------------------------------------------------------------
# GET /api/v1/events/<id>/photo-report/
# ---------------------------------------------------------------------------

class EventPhotoReportListViewTest(APITestCase):
    URL = '/api/v1/events/{event_id}/photo-report/'

    def test_returns_photos_for_past_event(self):
        event = make_past_event(title='Прошедшее')
        EventPhotoReport.objects.create(event=event, image=make_image())
        EventPhotoReport.objects.create(event=event, image=make_image())
        response = self.client.get(self.URL.format(event_id=event.pk))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_returns_empty_for_future_event(self):
        event = make_event(title='Будущее', days_offset=5)
        EventPhotoReport.objects.create(event=event, image=make_image())
        response = self.client.get(self.URL.format(event_id=event.pk))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_returns_empty_when_no_photos(self):
        event = make_past_event()
        response = self.client.get(self.URL.format(event_id=event.pk))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_returns_empty_for_nonexistent_event(self):
        response = self.client.get(self.URL.format(event_id=99999))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_public_access_no_auth_required(self):
        event = make_past_event()
        response = self.client.get(self.URL.format(event_id=event.pk))
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_photos_ordered_by_order_field(self):
        event = make_past_event()
        EventPhotoReport.objects.create(event=event, image=make_image('z.png'), order=3)
        EventPhotoReport.objects.create(event=event, image=make_image('a.png'), order=1)
        EventPhotoReport.objects.create(event=event, image=make_image('b.png'), order=2)
        response = self.client.get(self.URL.format(event_id=event.pk))
        orders = [p['order'] for p in response.data]
        self.assertEqual(orders, [1, 2, 3])

    def test_response_contains_expected_fields(self):
        event = make_past_event()
        EventPhotoReport.objects.create(event=event, image=make_image())
        response = self.client.get(self.URL.format(event_id=event.pk))
        photo = response.data[0]
        self.assertIn('id', photo)
        self.assertIn('image', photo)
        self.assertIn('order', photo)


# ---------------------------------------------------------------------------
# EventSerializer — has_photo_report
# ---------------------------------------------------------------------------

class EventSerializerHasPhotoReportTest(TestCase):
    def test_has_photo_report_false_when_no_photos(self):
        event = make_past_event()
        data = EventSerializer(event).data
        self.assertFalse(data['has_photo_report'])

    def test_has_photo_report_true_when_photos_exist(self):
        event = make_past_event()
        EventPhotoReport.objects.create(event=event, image=make_image())
        data = EventSerializer(event).data
        self.assertTrue(data['has_photo_report'])

    def test_upcoming_event_has_photo_report_false(self):
        event = make_event(days_offset=3)
        data = EventSerializer(event).data
        self.assertFalse(data['has_photo_report'])

    def test_has_photo_report_included_in_archived_list(self):
        event = make_past_event(title='С фото')
        EventPhotoReport.objects.create(event=event, image=make_image())
        response = self.client.get('/api/v1/events/archived/')
        result = next(e for e in response.data['results'] if e['title'] == 'С фото')
        self.assertTrue(result['has_photo_report'])


class NewsCacheTest(APITestCase):
    """Версионный кэш новостей."""

    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_news_cache_hit_on_second_request(self):
        """Второй запрос к /news/ попадает в кэш."""
        News.objects.create(title='Новость 1', content='Текст')
        r1 = self.client.get('/api/v1/events/news/')
        v  = cache.get('events_news_cache_version', 1)
        self.assertIsNotNone(cache.get(f'events_news:{v}:'))
        r2 = self.client.get('/api/v1/events/news/')
        self.assertEqual(r1.data, r2.data)

    def test_post_save_news_bumps_version(self):
        """Создание новости инкрементирует версию кэша новостей."""
        self.client.get('/api/v1/events/news/')
        v_before = cache.get('events_news_cache_version', 1)
        News.objects.create(title='Свежая новость', content='...')
        self.assertGreater(cache.get('events_news_cache_version', 1), v_before)

    def test_after_invalidation_new_news_appears(self):
        """После инвалидации новая новость видна в ответе."""
        News.objects.create(title='Старая', content='...')
        self.client.get('/api/v1/events/news/')
        News.objects.create(title='Только что добавили', content='...')
        response = self.client.get('/api/v1/events/news/')
        titles = [n['title'] for n in response.data['results']]
        self.assertIn('Только что добавили', titles)

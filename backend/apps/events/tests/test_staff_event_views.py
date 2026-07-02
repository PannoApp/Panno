import io

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.events.models import Event

User = get_user_model()

LIST_URL = '/api/v1/events/admin/events/'


def _detail(pk):
    return f'{LIST_URL}{pk}/'


def _make_image(name='img.jpg', width=400, height=400):
    img = Image.new('RGB', (width, height), color=(120, 120, 120))
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/jpeg')


def _landscape(name='landscape.jpg'):
    return _make_image(name, width=1600, height=900)


def _square(name='square.jpg'):
    return _make_image(name, width=400, height=400)


def _make_event(title='Мероприятие', is_active=True, days=7):
    return Event.objects.create(
        title=title,
        description='Описание',
        date_time=timezone.now() + timezone.timedelta(days=days),
        image=_landscape(f'ev_{title[:4]}.jpg'),
        is_active=is_active,
    )


def _base_payload(**overrides):
    data = {
        'title': 'Тестовое мероприятие',
        'description': 'Описание',
        'date_time': (timezone.now() + timezone.timedelta(days=7)).isoformat(),
        'format': 'open',
    }
    data.update(overrides)
    return data


class StaffEventViewSetTest(APITestCase):

    def setUp(self):
        cache.clear()
        self.staff = User.objects.create_user(phone='+77090000001', role='content_manager')
        self.user = User.objects.create_user(phone='+77090000002')

    def tearDown(self):
        cache.clear()

    def _auth(self, user):
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    # ------------------------------------------------------------------
    # Auth / permissions
    # ------------------------------------------------------------------

    def test_list_requires_auth(self):
        response = self.client.get(LIST_URL)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_requires_staff(self):
        self._auth(self.user)
        response = self.client.get(LIST_URL)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # ------------------------------------------------------------------
    # List
    # ------------------------------------------------------------------

    def test_list_includes_inactive(self):
        _make_event(title='Активное', is_active=True)
        _make_event(title='Неактивное', is_active=False)
        self._auth(self.staff)
        response = self.client.get(LIST_URL)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [e['title'] for e in response.data]
        self.assertIn('Активное', titles)
        self.assertIn('Неактивное', titles)

    # ------------------------------------------------------------------
    # Create
    # ------------------------------------------------------------------

    def test_create_event_multipart(self):
        self._auth(self.staff)
        payload = _base_payload()
        payload['image'] = _square()  # non-16:9 — mixin crops it
        response = self.client.post(LIST_URL, payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        event = Event.objects.get(pk=response.data['id'])
        event.refresh_from_db()
        with default_storage.open(event.image.name, 'rb') as f:
            img = Image.open(f)
            img.load()
            w, h = img.size
        self.assertAlmostEqual(w / h, 16 / 9, delta=0.05)

    def test_create_without_image_returns_400(self):
        self._auth(self.staff)
        response = self.client.post(LIST_URL, _base_payload(), format='multipart')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('image', response.data)

    # ------------------------------------------------------------------
    # Partial update
    # ------------------------------------------------------------------

    def test_partial_update_title(self):
        self._auth(self.staff)
        event = _make_event()
        response = self.client.patch(_detail(event.pk), {'title': 'Новое'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        event.refresh_from_db()
        self.assertEqual(event.title, 'Новое')

    def test_partial_update_is_active(self):
        self._auth(self.staff)
        event = _make_event(is_active=True)
        response = self.client.patch(_detail(event.pk), {'is_active': False}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        event.refresh_from_db()
        self.assertFalse(event.is_active)

    def test_partial_update_with_new_image(self):
        self._auth(self.staff)
        event = _make_event()
        event.refresh_from_db()
        old_name = event.image.name
        self.assertTrue(default_storage.exists(old_name))

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.patch(
                _detail(event.pk),
                {'image': _landscape('replacement.jpg')},
                format='multipart',
            )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(default_storage.exists(old_name))

    # ------------------------------------------------------------------
    # Delete
    # ------------------------------------------------------------------

    def test_delete_event(self):
        self._auth(self.staff)
        event = _make_event()
        event.refresh_from_db()
        file_name = event.image.name
        self.assertTrue(default_storage.exists(file_name))

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.delete(_detail(event.pk))

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Event.objects.filter(pk=event.pk).exists())
        self.assertFalse(default_storage.exists(file_name))

    def test_delete_event_invalidates_cache(self):
        self._auth(self.staff)
        event = _make_event()
        v_before = cache.get('events_upcoming_cache_version', 1)

        with self.captureOnCommitCallbacks(execute=True):
            self.client.delete(_detail(event.pk))

        v_after = cache.get('events_upcoming_cache_version', 1)
        self.assertGreater(v_after, v_before)

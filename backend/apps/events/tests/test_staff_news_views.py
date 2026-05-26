import io

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.events.models import News

User = get_user_model()

LIST_URL = '/api/v1/events/staff/news/'


def _detail(pk):
    return f'{LIST_URL}{pk}/'


def _make_image(name='news.jpg', width=400, height=400):
    img = Image.new('RGB', (width, height), color=(80, 80, 80))
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/jpeg')


def _make_news(title='Новость', with_image=False):
    kwargs = {'title': title, 'content': 'Текст новости'}
    if with_image:
        kwargs['image'] = _make_image(f'cover_{title[:4]}.jpg')
    return News.objects.create(**kwargs)


class StaffNewsViewSetTest(APITestCase):

    def setUp(self):
        cache.clear()
        self.staff = User.objects.create_user(phone='+77090000010', role='content_manager')
        self.user = User.objects.create_user(phone='+77090000011')

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
    # Create
    # ------------------------------------------------------------------

    def test_create_news_without_image(self):
        self._auth(self.staff)
        payload = {'title': 'Новость без фото', 'content': 'Контент'}
        response = self.client.post(LIST_URL, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(News.objects.filter(title='Новость без фото').exists())

    def test_create_news_with_image(self):
        self._auth(self.staff)
        payload = {
            'title': 'Новость с фото',
            'content': 'Контент',
            'image': _make_image('upload.jpg', width=400, height=400),  # квадрат → кроп до 16:9
        }
        response = self.client.post(LIST_URL, payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        news = News.objects.get(pk=response.data['id'])
        news.refresh_from_db()
        with default_storage.open(news.image.name, 'rb') as f:
            img = Image.open(f)
            img.load()
            w, h = img.size
        self.assertAlmostEqual(w / h, 16 / 9, delta=0.05)

    # ------------------------------------------------------------------
    # Partial update
    # ------------------------------------------------------------------

    def test_partial_update_content(self):
        self._auth(self.staff)
        news = _make_news()
        response = self.client.patch(_detail(news.pk), {'content': 'новый текст'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        news.refresh_from_db()
        self.assertEqual(news.content, 'новый текст')

    def test_add_image_to_existing_news(self):
        self._auth(self.staff)
        news = _make_news(with_image=False)
        self.assertFalse(bool(news.image))

        response = self.client.patch(
            _detail(news.pk),
            {'image': _make_image('added.jpg')},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        news.refresh_from_db()
        self.assertTrue(bool(news.image))

    # ------------------------------------------------------------------
    # Delete
    # ------------------------------------------------------------------

    def test_delete_news_without_image(self):
        self._auth(self.staff)
        news = _make_news(with_image=False)
        response = self.client.delete(_detail(news.pk))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(News.objects.filter(pk=news.pk).exists())

    def test_delete_news_with_image(self):
        self._auth(self.staff)
        news = _make_news(with_image=True)
        news.refresh_from_db()
        file_name = news.image.name
        self.assertTrue(default_storage.exists(file_name))

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.delete(_detail(news.pk))

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(News.objects.filter(pk=news.pk).exists())
        self.assertFalse(default_storage.exists(file_name))

    def test_delete_invalidates_cache(self):
        self._auth(self.staff)
        news = _make_news()
        # Фиксируем текущую версию (или 0 если ключ ещё не существует)
        v_before = cache.get('events_news_cache_version', 0)

        self.client.delete(_detail(news.pk))

        v_after = cache.get('events_news_cache_version', 0)
        self.assertGreater(v_after, v_before)

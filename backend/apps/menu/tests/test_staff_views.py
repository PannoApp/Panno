import io
import sys
from unittest.mock import MagicMock as _MagicMock, patch

# ffmpeg присутствует только в Docker-образе; stub чтобы модуль загрузился в CI
if 'ffmpeg' not in sys.modules:
    sys.modules['ffmpeg'] = _MagicMock()

from django.contrib.auth import get_user_model
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.menu.models import Category, Dish

User = get_user_model()

STAFF_URL = '/api/v1/menu/staff/dishes/'


def _make_image(name='dish.png', width=160, height=90):
    """16×9 PNG — проходит AutoCropImageMixin без ошибок."""
    from PIL import Image
    img = Image.new('RGB', (width, height), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/png')


def _bearer(user):
    return f'Bearer {RefreshToken.for_user(user).access_token}'


class StaffDishViewSetTest(APITestCase):

    def setUp(self):
        self.category = Category.objects.create(name='Горячие', order=1)

        # Обычный пользователь — без роли, is_staff=False
        self.user = User.objects.create_user(phone='+70000000001', password='x')

        # Staff — role синхронизирует is_staff=True автоматически (см. User.save)
        self.staff = User.objects.create_user(
            phone='+70000000002', password='x', role='content_manager',
        )

    def _auth(self, user):
        self.client.credentials(HTTP_AUTHORIZATION=_bearer(user))

    def _create_dish(self, name='Плов'):
        """Создаёт блюдо через ORM и возвращает обновлённый экземпляр из БД."""
        dish = Dish.objects.create(
            name=name,
            price='1000.00',
            category=self.category,
            image=_make_image(f'{name}.png'),
        )
        dish.refresh_from_db()
        return dish

    # ------------------------------------------------------------------
    # Auth / permission guards
    # ------------------------------------------------------------------

    def test_list_requires_staff(self):
        """Анонимный запрос → 401."""
        response = self.client.get(STAFF_URL)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_requires_staff_role(self):
        """Обычный авторизованный пользователь без роли → 403."""
        self._auth(self.user)
        response = self.client.get(STAFF_URL)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # ------------------------------------------------------------------
    # List
    # ------------------------------------------------------------------

    def test_list_includes_inactive(self):
        """Staff видит и активные, и неактивные блюда."""
        Dish.objects.create(
            name='Активное', price='500.00', category=self.category,
            image=_make_image('a.png'), is_active=True,
        )
        Dish.objects.create(
            name='Неактивное', price='500.00', category=self.category,
            image=_make_image('b.png'), is_active=False,
        )
        self._auth(self.staff)
        response = self.client.get(STAFF_URL)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data]
        self.assertIn('Активное', names)
        self.assertIn('Неактивное', names)

    # ------------------------------------------------------------------
    # Create
    # ------------------------------------------------------------------

    def test_create_dish_multipart(self):
        """POST multipart с корректным изображением → 201; AutoCropImageMixin конвертирует в JPEG."""
        self._auth(self.staff)
        data = {
            'name': 'Бешбармак',
            'price': '2000.00',
            'category': self.category.pk,
            'is_active': True,
            'image': _make_image('besh.png'),
        }
        response = self.client.post(STAFF_URL, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        dish = Dish.objects.get(pk=response.data['id'])
        # AutoCropImageMixin сохраняет результат кропа как JPEG с UUID-именем
        self.assertTrue(dish.image.name.endswith('.jpg'), dish.image.name)

    def test_create_without_image_returns_400(self):
        """POST без поля image → 400 с указанием поля."""
        self._auth(self.staff)
        data = {
            'name': 'Без фото',
            'price': '1000.00',
            'category': self.category.pk,
        }
        response = self.client.post(STAFF_URL, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('image', response.data)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def test_partial_update_name(self):
        """PATCH только поля name → 200, имя блюда изменено в БД."""
        dish = self._create_dish('Лагман')
        self._auth(self.staff)
        response = self.client.patch(
            f'{STAFF_URL}{dish.pk}/',
            {'name': 'Лагман обновлённый'},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dish.refresh_from_db()
        self.assertEqual(dish.name, 'Лагман обновлённый')

    def test_partial_update_with_new_image(self):
        """PATCH с новым изображением → 200; старый файл удалён из storage.

        captureOnCommitCallbacks нужен: django-cleanup откладывает удаление
        через on_commit, а TestCase никогда не коммитит транзакцию.
        """
        dish = self._create_dish('Манты')
        old_image_name = dish.image.name
        self.assertTrue(
            default_storage.exists(old_image_name),
            f'Старое изображение должно существовать перед PATCH: {old_image_name}',
        )

        self._auth(self.staff)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.patch(
                f'{STAFF_URL}{dish.pk}/',
                {'image': _make_image('manty_new.png')},
                format='multipart',
            )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(
            default_storage.exists(old_image_name),
            f'Старое изображение должно быть удалено после PATCH: {old_image_name}',
        )

    # ------------------------------------------------------------------
    # Delete
    # ------------------------------------------------------------------

    def test_delete_dish(self):
        """DELETE → 204; запись и файл на storage удалены.

        captureOnCommitCallbacks нужен: django-cleanup откладывает удаление
        через on_commit, а TestCase никогда не коммитит транзакцию.
        """
        dish = self._create_dish('Самса')
        img_name = dish.image.name
        self.assertTrue(
            default_storage.exists(img_name),
            f'Изображение должно существовать перед DELETE: {img_name}',
        )

        self._auth(self.staff)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.delete(f'{STAFF_URL}{dish.pk}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Dish.objects.filter(pk=dish.pk).exists())
        self.assertFalse(
            default_storage.exists(img_name),
            f'Изображение должно быть удалено из storage после DELETE: {img_name}',
        )

    # ------------------------------------------------------------------
    # Video status
    # ------------------------------------------------------------------

    def test_create_dish_with_video(self):
        """POST multipart с image + video → 201, video_status='pending' в ответе."""
        self._auth(self.staff)
        data = {
            'name': 'Видеоблюдо',
            'price': '1500.00',
            'category': self.category.pk,
            'image': _make_image('video_dish.png'),
            'video': SimpleUploadedFile('clip.mp4', b'fake-video-data', content_type='video/mp4'),
        }
        response = self.client.post(STAFF_URL, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['video_status'], 'pending')

    def test_create_dish_without_video(self):
        """POST только с image → 201, video_status='pending' (дефолт модели)."""
        self._auth(self.staff)
        data = {
            'name': 'Без видео',
            'price': '800.00',
            'category': self.category.pk,
            'image': _make_image('no_video.png'),
        }
        response = self.client.post(STAFF_URL, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['video_status'], 'pending')

    def test_partial_update_video_resets_to_pending(self):
        """PATCH с новым video на блюдо с video_status='ready' → 200, video_status='pending'.

        Мокируем process_dish_video.delay, чтобы задача не выполнялась синхронно
        (CELERY_TASK_ALWAYS_EAGER=True) и не перезаписывала статус в PROCESSING/READY.
        """
        dish = self._create_dish('Лагман с видео')
        dish.video_status = Dish.VideoStatus.READY
        dish.save(update_fields=['video_status'])

        self._auth(self.staff)
        with patch('apps.menu.tasks.process_dish_video.delay'):
            response = self.client.patch(
                f'{STAFF_URL}{dish.pk}/',
                {'video': SimpleUploadedFile('new_clip.mp4', b'new-video', content_type='video/mp4')},
                format='multipart',
            )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dish.refresh_from_db()
        self.assertEqual(dish.video_status, Dish.VideoStatus.PENDING)

    def test_video_status_in_response(self):
        """GET detail → ответ содержит поля video_status и video_url."""
        dish = self._create_dish('Бешбармак')
        self._auth(self.staff)
        response = self.client.get(f'{STAFF_URL}{dish.pk}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('video_status', response.data)
        self.assertIn('video_url', response.data)

    def test_invalid_video_format_returns_400(self):
        """PATCH с файлом content_type='image/jpeg' → 400."""
        dish = self._create_dish('Манты видео')
        self._auth(self.staff)
        response = self.client.patch(
            f'{STAFF_URL}{dish.pk}/',
            {'video': SimpleUploadedFile('bad.jpg', b'not-a-video', content_type='image/jpeg')},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('video', response.data)

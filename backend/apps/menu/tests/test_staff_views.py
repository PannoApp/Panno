import io
import sys
from unittest.mock import MagicMock as _MagicMock

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

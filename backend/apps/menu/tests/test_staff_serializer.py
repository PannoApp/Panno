import io
import sys
from unittest.mock import MagicMock as _MagicMock

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import RequestFactory, TestCase

# ffmpeg is only available inside the Docker image; stub it out so the module loads.
if 'ffmpeg' not in sys.modules:
    sys.modules['ffmpeg'] = _MagicMock()

from apps.menu.models import Allergen, Category, Dish, Tag
from apps.menu.serializers import StaffDishSerializer


def _make_landscape_image(name='dish.png'):
    """16×9 PNG — satisfies AutoCropImageMixin's ratio check."""
    from PIL import Image
    img = Image.new('RGB', (160, 90), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/png')


def _make_request(scheme='http', host='testserver'):
    request = RequestFactory().get('/')
    request.META['SERVER_NAME'] = host
    request.META['SERVER_PORT'] = '80'
    return request


class StaffDishSerializerTest(TestCase):
    def setUp(self):
        self.category = Category.objects.create(name='Горячие', order=1)
        self.tag = Tag.objects.create(name='Хит')
        self.allergen = Allergen.objects.create(name='Глютен')

    def _valid_data(self, **overrides):
        data = {
            'name': 'Стейк',
            'description': 'Вкусно',
            'price': '1500.00',
            'category': self.category.pk,
            'tags': [],
            'allergens': [],
            'weight': '250',
            'story': '',
            'is_active': True,
            'image': _make_landscape_image(),
        }
        data.update(overrides)
        return data

    # ------------------------------------------------------------------
    # test_valid_create_data
    # ------------------------------------------------------------------

    def test_valid_create_data(self):
        serializer = StaffDishSerializer(data=self._valid_data())
        self.assertTrue(serializer.is_valid(), serializer.errors)

    # ------------------------------------------------------------------
    # test_create_without_image_invalid
    # ------------------------------------------------------------------

    def test_create_without_image_invalid(self):
        data = self._valid_data()
        data.pop('image')
        serializer = StaffDishSerializer(data=data)
        self.assertFalse(serializer.is_valid())
        self.assertIn('image', serializer.errors)

    # ------------------------------------------------------------------
    # test_partial_update_without_image_valid
    # ------------------------------------------------------------------

    def test_partial_update_without_image_valid(self):
        dish = Dish.objects.create(
            name='Борщ',
            description='Описание',
            price='800.00',
            category=self.category,
            image=_make_landscape_image('borsh.png'),
        )
        serializer = StaffDishSerializer(
            instance=dish,
            data={'name': 'Борщ обновлённый', 'price': '900.00'},
            partial=True,
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)

    # ------------------------------------------------------------------
    # test_category_accepts_int_id
    # ------------------------------------------------------------------

    def test_category_accepts_int_id(self):
        serializer = StaffDishSerializer(data=self._valid_data(category=self.category.pk))
        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data['category'], self.category)

    # ------------------------------------------------------------------
    # test_image_url_is_absolute
    # ------------------------------------------------------------------

    def test_image_url_is_absolute(self):
        dish = Dish.objects.create(
            name='Плов',
            description='',
            price='1200.00',
            category=self.category,
            image=_make_landscape_image('plov.png'),
        )
        serializer = StaffDishSerializer(dish, context={'request': _make_request()})
        url = serializer.data['image_url']
        self.assertIsNotNone(url)
        self.assertTrue(url.startswith(('http://', 'https://')), f'Expected absolute URL, got: {url}')

    # ------------------------------------------------------------------
    # test_video_field_is_optional_on_create
    # ------------------------------------------------------------------

    def test_video_field_is_optional_on_create(self):
        serializer = StaffDishSerializer(data=self._valid_data())
        self.assertTrue(serializer.is_valid(), serializer.errors)

    # ------------------------------------------------------------------
    # test_video_field_accepts_mp4
    # ------------------------------------------------------------------

    def test_video_field_accepts_mp4(self):
        video = SimpleUploadedFile('clip.mp4', b'fake-video-data', content_type='video/mp4')
        serializer = StaffDishSerializer(data=self._valid_data(video=video))
        self.assertTrue(serializer.is_valid(), serializer.errors)

    # ------------------------------------------------------------------
    # test_video_field_rejects_text
    # ------------------------------------------------------------------

    def test_video_field_rejects_text(self):
        bad_file = SimpleUploadedFile('clip.txt', b'not-a-video', content_type='text/plain')
        serializer = StaffDishSerializer(data=self._valid_data(video=bad_file))
        self.assertFalse(serializer.is_valid())
        self.assertIn('video', serializer.errors)

    # ------------------------------------------------------------------
    # test_video_status_is_readonly
    # ------------------------------------------------------------------

    def test_video_status_is_readonly(self):
        data = self._valid_data()
        data['video_status'] = 'ready'
        serializer = StaffDishSerializer(data=data)
        self.assertTrue(serializer.is_valid(), serializer.errors)
        # read_only поле не попадает в validated_data
        self.assertNotIn('video_status', serializer.validated_data)

    # ------------------------------------------------------------------
    # test_video_url_null_when_not_processed
    # ------------------------------------------------------------------

    def test_video_url_null_when_not_processed(self):
        dish = Dish.objects.create(
            name='Самса',
            description='',
            price='500.00',
            category=self.category,
            image=_make_landscape_image('samsa.png'),
        )
        serializer = StaffDishSerializer(dish, context={'request': _make_request()})
        self.assertIsNone(serializer.data['video_url'])

    # ------------------------------------------------------------------
    # test_video_url_absolute_when_processed
    # ------------------------------------------------------------------

    def test_video_url_absolute_when_processed(self):
        dish = Dish.objects.create(
            name='Бешбармак',
            description='',
            price='2000.00',
            category=self.category,
            image=_make_landscape_image('besh.png'),
            video_processed=SimpleUploadedFile('besh.mp4', b'data', content_type='video/mp4'),
        )
        serializer = StaffDishSerializer(dish, context={'request': _make_request()})
        url = serializer.data['video_url']
        self.assertIsNotNone(url)
        self.assertTrue(url.startswith(('http://', 'https://')), f'Expected absolute URL, got: {url}')

import io
from unittest.mock import MagicMock

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image

from apps.events.models import News
from apps.events.serializers import StaffNewsSerializer


def _make_image(name='news.jpg'):
    img = Image.new('RGB', (100, 100), color=(50, 50, 50))
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/jpeg')


class StaffNewsSerializerTest(TestCase):

    def test_valid_create_without_image(self):
        s = StaffNewsSerializer(data={'title': 'Заголовок', 'content': 'Текст новости'})
        self.assertTrue(s.is_valid(), s.errors)

    def test_valid_create_with_image(self):
        s = StaffNewsSerializer(data={
            'title': 'Заголовок',
            'content': 'Текст новости',
            'image': _make_image(),
        })
        self.assertTrue(s.is_valid(), s.errors)

    def test_title_required(self):
        s = StaffNewsSerializer(data={'content': 'Текст новости'})
        self.assertFalse(s.is_valid())
        self.assertIn('title', s.errors)

    def test_content_required(self):
        s = StaffNewsSerializer(data={'title': 'Заголовок'})
        self.assertFalse(s.is_valid())
        self.assertIn('content', s.errors)

    def test_image_url_none_when_no_image(self):
        news = News.objects.create(title='Без картинки', content='Текст')
        s = StaffNewsSerializer(news)
        self.assertIsNone(s.data['image_url'])

    def test_image_url_absolute_when_image_set(self):
        news = News.objects.create(
            title='С картинкой',
            content='Текст',
            image=_make_image('cover.jpg'),
        )
        mock_request = MagicMock()
        mock_request.build_absolute_uri.side_effect = lambda url: f'http://testserver{url}'
        s = StaffNewsSerializer(news, context={'request': mock_request})
        self.assertTrue(s.data['image_url'].startswith('http://'))

import io
from decimal import Decimal
from unittest.mock import MagicMock

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIRequestFactory

from apps.events.models import Event
from apps.events.serializers import StaffEventSerializer


def _make_landscape_image(name='event.jpg'):
    img = Image.new('RGB', (160, 90), color=(100, 100, 100))
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/jpeg')


def _base_data(**overrides):
    data = {
        'title': 'Тестовое мероприятие',
        'description': 'Описание',
        'date_time': (timezone.now() + timezone.timedelta(days=7)).isoformat(),
        'format': 'open',
    }
    data.update(overrides)
    return data


class StaffEventSerializerTest(TestCase):

    def test_valid_create_with_image(self):
        data = _base_data()
        data['image'] = _make_landscape_image()
        s = StaffEventSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)

    def test_create_without_image_invalid(self):
        s = StaffEventSerializer(data=_base_data())
        self.assertFalse(s.is_valid())
        self.assertIn('image', s.errors)

    def test_partial_update_without_image_valid(self):
        event = Event.objects.create(
            title='Существующее',
            description='Описание',
            date_time=timezone.now() + timezone.timedelta(days=3),
            image=_make_landscape_image('existing.jpg'),
            format='open',
        )
        s = StaffEventSerializer(
            instance=event,
            data={'title': 'Обновлённое название'},
            partial=True,
        )
        self.assertTrue(s.is_valid(), s.errors)

    def test_format_choices_validation(self):
        data = _base_data(format='invalid')
        data['image'] = _make_landscape_image()
        s = StaffEventSerializer(data=data)
        self.assertFalse(s.is_valid())
        self.assertIn('format', s.errors)

    def test_image_url_is_absolute(self):
        event = Event.objects.create(
            title='С обложкой',
            description='Описание',
            date_time=timezone.now() + timezone.timedelta(days=5),
            image=_make_landscape_image('cover.jpg'),
            format='open',
        )
        mock_request = MagicMock()
        mock_request.build_absolute_uri.side_effect = lambda url: f'http://testserver{url}'
        s = StaffEventSerializer(event, context={'request': mock_request})
        self.assertTrue(s.data['image_url'].startswith('http://'))

    def test_price_nullable(self):
        data_null = _base_data(price=None)
        data_null['image'] = _make_landscape_image()
        s_null = StaffEventSerializer(data=data_null)
        self.assertTrue(s_null.is_valid(), s_null.errors)

        data_value = _base_data(price='1500.00')
        data_value['image'] = _make_landscape_image()
        s_value = StaffEventSerializer(data=data_value)
        self.assertTrue(s_value.is_valid(), s_value.errors)
        self.assertEqual(s_value.validated_data['price'], Decimal('1500.00'))

    def test_occupied_places_is_readonly(self):
        data = _base_data(occupied_places=99)
        data['image'] = _make_landscape_image()
        s = StaffEventSerializer(data=data)
        self.assertTrue(s.is_valid(), s.errors)
        self.assertNotIn('occupied_places', s.validated_data)

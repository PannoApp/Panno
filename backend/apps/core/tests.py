from datetime import time as dt_time
from unittest.mock import MagicMock, patch

from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from .models import RestaurantInfo, AppVersion


# ---------------------------------------------------------------------------
# Модель ресторана (синглтон)
# ---------------------------------------------------------------------------

class RestaurantInfoModelTest(TestCase):
    def test_load_returns_singleton(self):
        info = RestaurantInfo.load()
        self.assertIsNotNone(info)
        self.assertEqual(info.pk, 1)

    def test_load_always_returns_same_record(self):
        a = RestaurantInfo.load()
        b = RestaurantInfo.load()
        self.assertEqual(a.pk, b.pk)
        self.assertEqual(RestaurantInfo.objects.count(), 1)

    def test_save_forces_pk_1(self):
        info = RestaurantInfo(address='ул. Панфилова, 98', working_hours='12:00–00:00')
        info.save()
        self.assertEqual(info.pk, 1)
        self.assertEqual(RestaurantInfo.objects.count(), 1)

    def test_second_save_updates_not_creates(self):
        RestaurantInfo.load()
        info = RestaurantInfo(address='Новый адрес', working_hours='10:00–22:00')
        info.save()
        self.assertEqual(RestaurantInfo.objects.count(), 1)
        self.assertEqual(RestaurantInfo.objects.get(pk=1).address, 'Новый адрес')

    def test_delete_is_noop(self):
        info = RestaurantInfo.load()
        info.delete()
        self.assertEqual(RestaurantInfo.objects.count(), 1)

    def test_str(self):
        info = RestaurantInfo.load()
        self.assertEqual(str(info), 'Информация о ресторане')

    def test_optional_links_are_nullable(self):
        info = RestaurantInfo.load()
        info.tour_link = None
        info.twogis_link = None
        info.save()
        loaded = RestaurantInfo.objects.get(pk=1)
        self.assertIsNone(loaded.tour_link)
        self.assertIsNone(loaded.twogis_link)


# ---------------------------------------------------------------------------
# GET /api/core/info/
# ---------------------------------------------------------------------------

class RestaurantInfoViewTest(APITestCase):
    def setUp(self):
        info = RestaurantInfo.load()
        info.address = 'г. Алматы, ул. Панфилова, 98'
        info.working_hours = 'Пн–Вс: 12:00–00:00'
        info.save()

    def test_get_returns_200(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_response_contains_required_fields(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('address', response.data)
        self.assertIn('working_hours', response.data)
        self.assertIn('tour_link', response.data)
        self.assertIn('twogis_link', response.data)

    def test_response_values_match_db(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['address'], 'г. Алматы, ул. Панфилова, 98')
        self.assertEqual(response.data['working_hours'], 'Пн–Вс: 12:00–00:00')

    def test_optional_links_can_be_null(self):
        response = self.client.get('/api/v1/core/info/')
        # tour_link and twogis_link are null when not set
        self.assertIsNone(response.data['tour_link'])
        self.assertIsNone(response.data['twogis_link'])


# ---------------------------------------------------------------------------
# RestaurantInfo.is_open_now property
# ---------------------------------------------------------------------------

class RestaurantInfoIsOpenNowTest(TestCase):
    def _make_info(self, working_hours):
        info = RestaurantInfo.load()
        info.working_hours = working_hours
        info.save()
        return info

    def _mock_local_time(self, hour, minute):
        mock_dt = MagicMock()
        mock_dt.time.return_value = dt_time(hour, minute)
        return mock_dt

    def test_returns_none_when_working_hours_empty(self):
        info = self._make_info('')
        self.assertIsNone(info.is_open_now)

    def test_returns_none_when_format_unrecognized(self):
        info = self._make_info('всегда открыто')
        self.assertIsNone(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_returns_true_within_normal_hours(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(15, 0)
        info = self._make_info('Пн–Вс: 12:00–22:00')
        self.assertTrue(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_returns_false_before_opening(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(10, 0)
        info = self._make_info('Пн–Вс: 12:00–22:00')
        self.assertFalse(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_returns_false_after_closing(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(23, 0)
        info = self._make_info('Пн–Вс: 12:00–22:00')
        self.assertFalse(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_midnight_crossing_returns_true_after_open(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(23, 0)
        info = self._make_info('Пн–Вс: 20:00–02:00')
        self.assertTrue(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_midnight_crossing_returns_true_before_close(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(1, 30)
        info = self._make_info('Пн–Вс: 20:00–02:00')
        self.assertTrue(info.is_open_now)

    @patch('apps.core.models.timezone.localtime')
    @patch('apps.core.models.timezone.now')
    def test_midnight_crossing_returns_false_outside_hours(self, mock_now, mock_localtime):
        mock_localtime.return_value = self._mock_local_time(10, 0)
        info = self._make_info('Пн–Вс: 20:00–02:00')
        self.assertFalse(info.is_open_now)


# ---------------------------------------------------------------------------
# RestaurantInfo hero media + concept fields
# ---------------------------------------------------------------------------

class RestaurantInfoHeroFieldsTest(APITestCase):
    def setUp(self):
        self.info = RestaurantInfo.load()

    def test_concept_description_defaults_to_empty_string(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('concept_description', response.data)
        self.assertEqual(response.data['concept_description'], '')

    def test_hero_image_defaults_to_null(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('hero_image', response.data)
        self.assertIsNone(response.data['hero_image'])

    def test_hero_video_url_defaults_to_empty_string(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('hero_video_url', response.data)
        self.assertEqual(response.data['hero_video_url'], '')

    def test_concept_description_reflects_saved_value(self):
        self.info.concept_description = 'Modern Nomad — кухня кочевников'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['concept_description'], 'Modern Nomad — кухня кочевников')

    def test_hero_video_url_reflects_saved_value(self):
        self.info.hero_video_url = 'https://cdn.example.com/hero.mp4'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['hero_video_url'], 'https://cdn.example.com/hero.mp4')


# ---------------------------------------------------------------------------
# GET /api/v1/core/app-version/
# ---------------------------------------------------------------------------

class AppVersionViewTest(APITestCase):
    def setUp(self):
        AppVersion.objects.create(
            platform='ios',
            min_version='1.0.0',
            latest_version='1.3.0',
            store_url='https://apps.apple.com/app/panno/id123',
        )
        AppVersion.objects.create(
            platform='android',
            min_version='1.1.0',
            latest_version='1.3.0',
            store_url='https://play.google.com/store/apps/details?id=kz.panno',
        )

    def test_ios_returns_200_with_correct_data(self):
        response = self.client.get('/api/v1/core/app-version/?platform=ios')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['platform'], 'ios')
        self.assertEqual(response.data['min_version'], '1.0.0')
        self.assertEqual(response.data['latest_version'], '1.3.0')

    def test_android_returns_200_with_correct_data(self):
        response = self.client.get('/api/v1/core/app-version/?platform=android')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['platform'], 'android')
        self.assertEqual(response.data['min_version'], '1.1.0')

    def test_unknown_platform_returns_404(self):
        response = self.client.get('/api/v1/core/app-version/?platform=windows')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_missing_platform_param_returns_404(self):
        response = self.client.get('/api/v1/core/app-version/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_no_auth_required(self):
        response = self.client.get('/api/v1/core/app-version/?platform=ios')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_response_contains_store_url_and_updated_at(self):
        response = self.client.get('/api/v1/core/app-version/?platform=ios')
        self.assertIn('store_url', response.data)
        self.assertIn('updated_at', response.data)

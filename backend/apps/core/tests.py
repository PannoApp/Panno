from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from .models import RestaurantInfo


# ---------------------------------------------------------------------------
# RestaurantInfo model (singleton)
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
        response = self.client.get('/api/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_response_contains_required_fields(self):
        response = self.client.get('/api/core/info/')
        self.assertIn('address', response.data)
        self.assertIn('working_hours', response.data)
        self.assertIn('tour_link', response.data)
        self.assertIn('twogis_link', response.data)

    def test_response_values_match_db(self):
        response = self.client.get('/api/core/info/')
        self.assertEqual(response.data['address'], 'г. Алматы, ул. Панфилова, 98')
        self.assertEqual(response.data['working_hours'], 'Пн–Вс: 12:00–00:00')

    def test_optional_links_can_be_null(self):
        response = self.client.get('/api/core/info/')
        # tour_link and twogis_link are null when not set
        self.assertIsNone(response.data['tour_link'])
        self.assertIsNone(response.data['twogis_link'])

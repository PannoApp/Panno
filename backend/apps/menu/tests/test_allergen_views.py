from rest_framework import status
from rest_framework.test import APITestCase

from apps.menu.models import Allergen

ALLERGEN_URL = '/api/v1/menu/allergens/'


class AllergenListViewTest(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.a1 = Allergen.objects.create(name='Глютен')
        cls.a2 = Allergen.objects.create(name='Арахис')
        cls.a3 = Allergen.objects.create(name='Молоко')

    def test_allergen_list_public(self):
        response = self.client.get(ALLERGEN_URL)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_allergen_list_returns_all(self):
        response = self.client.get(ALLERGEN_URL)
        ids = {item['id'] for item in response.data}
        self.assertIn(self.a1.id, ids)
        self.assertIn(self.a2.id, ids)
        self.assertIn(self.a3.id, ids)

    def test_allergen_list_sorted_by_name(self):
        response = self.client.get(ALLERGEN_URL)
        names = [item['name'] for item in response.data]
        self.assertEqual(names, sorted(names))

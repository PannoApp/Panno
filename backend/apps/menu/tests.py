from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Category, Dish, Tag, Allergen

# Minimal 1×1 PNG for ImageField
_PNG = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01'
    b'\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00'
    b'\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18'
    b'\xd8N\x00\x00\x00\x00IEND\xaeB`\x82'
)


def make_image(name='dish.png'):
    return SimpleUploadedFile(name, _PNG, content_type='image/png')


def make_category(name='Горячие', order=1):
    return Category.objects.create(name=name, order=order)


def make_dish(category, name='Блюдо', is_active=True, price='500.00'):
    return Dish.objects.create(
        name=name,
        description='Описание',
        price=price,
        category=category,
        image=make_image(f'{name}.png'),
        is_active=is_active,
    )


# ---------------------------------------------------------------------------
# GET /api/menu/categories/
# ---------------------------------------------------------------------------

class CategoryListViewTest(APITestCase):
    def test_returns_all_categories_ordered(self):
        Category.objects.create(name='Напитки', order=3)
        Category.objects.create(name='Салаты', order=2)
        Category.objects.create(name='Горячие', order=1)
        response = self.client.get('/api/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        orders = [c['order'] for c in response.data]
        self.assertEqual(orders, sorted(orders))

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_returns_all_categories_without_pagination(self):
        for i in range(25):
            Category.objects.create(name=f'Кат {i}', order=i)
        response = self.client.get('/api/menu/categories/')
        # No pagination — all items in a plain list
        self.assertIsInstance(response.data, list)
        self.assertEqual(len(response.data), 25)

    def test_empty_list_returns_200(self):
        response = self.client.get('/api/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])

    def test_response_contains_required_fields(self):
        Category.objects.create(name='Десерты', order=5)
        response = self.client.get('/api/menu/categories/')
        item = response.data[0]
        self.assertIn('id', item)
        self.assertIn('name', item)
        self.assertIn('order', item)


# ---------------------------------------------------------------------------
# GET /api/menu/dishes/
# ---------------------------------------------------------------------------

class DishListViewTest(APITestCase):
    def setUp(self):
        self.cat1 = make_category('Горячие', order=1)
        self.cat2 = make_category('Салаты', order=2)
        self.tag = Tag.objects.create(name='Хит')
        self.allergen = Allergen.objects.create(name='Глютен')

        self.dish1 = make_dish(self.cat1, name='Стейк')
        self.dish1.tags.add(self.tag)

        self.dish2 = make_dish(self.cat2, name='Греческий салат')
        self.dish2.allergens.add(self.allergen)

        self.inactive = make_dish(self.cat1, name='Скрытое блюдо', is_active=False)

    def test_returns_only_active_dishes(self):
        response = self.client.get('/api/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertIn('Греческий салат', names)
        self.assertNotIn('Скрытое блюдо', names)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_filter_by_category_id(self):
        response = self.client.get(f'/api/menu/dishes/?category_id={self.cat1.pk}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertNotIn('Греческий салат', names)

    def test_filter_by_tag_id(self):
        response = self.client.get(f'/api/menu/dishes/?tag_id={self.tag.pk}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertNotIn('Греческий салат', names)

    def test_default_page_size_is_5(self):
        cat = make_category('Большая', order=10)
        for i in range(10):
            make_dish(cat, name=f'Блюдо {i}')
        response = self.client.get('/api/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(response.data['results']), 5)

    def test_response_contains_nested_category(self):
        response = self.client.get(f'/api/menu/dishes/?category_id={self.cat1.pk}')
        dish = response.data['results'][0]
        self.assertIn('category', dish)
        self.assertEqual(dish['category']['id'], self.cat1.pk)

    def test_response_contains_tags_and_allergens(self):
        response = self.client.get(f'/api/menu/dishes/?category_id={self.cat2.pk}')
        dish = response.data['results'][0]
        self.assertIn('tags', dish)
        self.assertIn('allergens', dish)
        allergen_names = [a['name'] for a in dish['allergens']]
        self.assertIn('Глютен', allergen_names)

    def test_pagination_next_link_present_when_more_items(self):
        cat = make_category('Огромная', order=20)
        for i in range(6):
            make_dish(cat, name=f'Доп {i}')
        response = self.client.get(f'/api/menu/dishes/?category_id={cat.pk}')
        self.assertIsNotNone(response.data.get('next'))


# ---------------------------------------------------------------------------
# Category model
# ---------------------------------------------------------------------------

class CategoryModelTest(TestCase):
    def test_str(self):
        cat = Category.objects.create(name='Напитки', order=1)
        self.assertEqual(str(cat), 'Напитки')


# ---------------------------------------------------------------------------
# Dish model
# ---------------------------------------------------------------------------

class DishModelTest(TestCase):
    def setUp(self):
        self.cat = make_category()

    def test_str(self):
        dish = make_dish(self.cat, name='Борщ')
        self.assertEqual(str(dish), 'Борщ')

    def test_inactive_dish_exists_in_db(self):
        make_dish(self.cat, name='Архивное', is_active=False)
        self.assertTrue(Dish.objects.filter(name='Архивное').exists())

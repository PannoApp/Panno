from datetime import time as dt_time
from unittest.mock import MagicMock, patch

from django.core.cache import cache
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from .models import RestaurantInfo, AppVersion, InteriorPhoto


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

    def test_hero_slides_defaults_to_empty_list(self):
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('hero_slides', response.data)
        self.assertEqual(response.data['hero_slides'], [])

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


# ---------------------------------------------------------------------------
# RestaurantInfo — новые поля карт и обратной связи (ТЗ 4.5)
# ---------------------------------------------------------------------------

class RestaurantInfoMapLinksTest(APITestCase):
    def setUp(self):
        self.info = RestaurantInfo.load()

    def test_response_contains_all_map_links(self):
        """Все три ссылки на карты должны быть в ответе (могут быть null)."""
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('twogis_link', response.data)
        self.assertIn('google_maps_link', response.data)
        self.assertIn('yandex_maps_link', response.data)

    def test_response_contains_feedback_url(self):
        """Ссылка на обратную связь должна быть в ответе."""
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('feedback_url', response.data)

    def test_map_links_reflect_saved_values(self):
        """Сохранённые ссылки на карты возвращаются корректно."""
        self.info.google_maps_link = 'https://maps.google.com/?q=panno'
        self.info.yandex_maps_link = 'https://yandex.kz/maps/?text=panno'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['google_maps_link'], 'https://maps.google.com/?q=panno')
        self.assertEqual(response.data['yandex_maps_link'], 'https://yandex.kz/maps/?text=panno')

    def test_map_links_nullable(self):
        """Незаполненные ссылки возвращаются как null."""
        response = self.client.get('/api/v1/core/info/')
        self.assertIsNone(response.data['google_maps_link'])
        self.assertIsNone(response.data['yandex_maps_link'])
        self.assertIsNone(response.data['feedback_url'])


# ---------------------------------------------------------------------------
# GET /api/v1/core/info/ — Поля депозита при бронировании (ТЗ 5)
# ---------------------------------------------------------------------------

class RestaurantInfoDepositTest(APITestCase):
    def setUp(self):
        self.info = RestaurantInfo.load()

    def test_response_contains_deposit_fields(self):
        """Поля депозита должны присутствовать в ответе."""
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('booking_deposit_required', response.data)
        self.assertIn('booking_deposit_note', response.data)

    def test_deposit_required_defaults_to_false(self):
        """По умолчанию депозит не требуется."""
        response = self.client.get('/api/v1/core/info/')
        self.assertFalse(response.data['booking_deposit_required'])

    def test_deposit_note_defaults_to_empty(self):
        """По умолчанию текст предупреждения пустой."""
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['booking_deposit_note'], '')

    def test_deposit_fields_reflect_saved_values(self):
        """Сохранённые значения полей депозита корректно возвращаются."""
        self.info.booking_deposit_required = True
        self.info.booking_deposit_note = 'Позвоните менеджеру для уточнения условий.'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertTrue(response.data['booking_deposit_required'])
        self.assertEqual(
            response.data['booking_deposit_note'],
            'Позвоните менеджеру для уточнения условий.',
        )


# ---------------------------------------------------------------------------
# GET /api/v1/core/interior/ — Галерея интерьера (ТЗ 4.3)
# ---------------------------------------------------------------------------

class InteriorPhotoListViewTest(APITestCase):
    def setUp(self):
        # Создаём фото в разных зонах для тестирования группировки и порядка
        InteriorPhoto.objects.create(zone='main_hall', order=1, caption='Главный зал, вид 1')
        InteriorPhoto.objects.create(zone='terrace',   order=1, caption='Терраса')
        InteriorPhoto.objects.create(zone='main_hall', order=2, caption='Главный зал, вид 2')

    def test_returns_200_without_auth(self):
        """Галерея доступна без авторизации."""
        response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_returns_all_photos(self):
        """Возвращаются все созданные фотографии."""
        response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(len(response.data), 3)

    def test_response_contains_required_fields(self):
        """Ответ содержит поля id, zone, zone_display, image, caption, order."""
        response = self.client.get('/api/v1/core/interior/')
        photo = response.data[0]
        for field in ('id', 'zone', 'zone_display', 'image', 'caption', 'order'):
            self.assertIn(field, photo)

    def test_zone_display_is_human_readable(self):
        """zone_display содержит читаемое название зоны, а не код."""
        response = self.client.get('/api/v1/core/interior/')
        # Все zone_display для main_hall должны быть 'Главный зал'
        main_hall_photos = [p for p in response.data if p['zone'] == 'main_hall']
        self.assertTrue(all(p['zone_display'] == 'Главный зал' for p in main_hall_photos))

    def test_sorted_by_zone_then_order(self):
        """Фотографии отсортированы: сначала по зоне, внутри зоны — по order."""
        response = self.client.get('/api/v1/core/interior/')
        zones = [p['zone'] for p in response.data]
        orders_in_main_hall = [p['order'] for p in response.data if p['zone'] == 'main_hall']
        # Зона main_hall идёт раньше terrace (алфавитный порядок m < t)
        self.assertEqual(zones[0], 'main_hall')
        # Внутри зоны order должен быть возрастающим
        self.assertEqual(orders_in_main_hall, sorted(orders_in_main_hall))

    def test_empty_gallery_returns_empty_list(self):
        """Если фотографий нет, возвращается пустой список."""
        InteriorPhoto.objects.all().delete()
        response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)


# ---------------------------------------------------------------------------
# Тест фильтрации блюд по нескольким тегам (ТЗ 4.2)
# ---------------------------------------------------------------------------

class DishMultiTagFilterTest(APITestCase):
    """
    Проверяем, что ?tag_ids=1,2 возвращает блюда с любым из указанных тегов,
    а не только с одним.
    """
    def setUp(self):
        from apps.menu.models import Category, Tag, Dish
        category = Category.objects.create(name='Основные', order=1)
        self.tag_vegan = Tag.objects.create(name='Вегетарианское')
        self.tag_spicy = Tag.objects.create(name='Острое')
        self.tag_gluten_free = Tag.objects.create(name='Без глютена')

        # Блюдо 1: только веганское
        self.dish_vegan = Dish.objects.create(
            name='Овощной плов', price='2500', category=category,
        )
        self.dish_vegan.tags.add(self.tag_vegan)

        # Блюдо 2: острое
        self.dish_spicy = Dish.objects.create(
            name='Острая баранина', price='3500', category=category,
        )
        self.dish_spicy.tags.add(self.tag_spicy)

        # Блюдо 3: без тегов из нашего списка
        self.dish_plain = Dish.objects.create(
            name='Хлеб', price='500', category=category,
        )
        self.dish_plain.tags.add(self.tag_gluten_free)

    def test_single_tag_filter(self):
        """?tag_ids=<id> возвращает только блюда с этим тегом."""
        response = self.client.get(f'/api/v1/menu/dishes/?tag_ids={self.tag_vegan.id}')
        self.assertEqual(response.status_code, 200)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Овощной плов', names)
        self.assertNotIn('Острая баранина', names)

    def test_multi_tag_filter_returns_union(self):
        """?tag_ids=1,2 возвращает блюда с тегом 1 ИЛИ тегом 2."""
        response = self.client.get(
            f'/api/v1/menu/dishes/?tag_ids={self.tag_vegan.id},{self.tag_spicy.id}'
        )
        self.assertEqual(response.status_code, 200)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Овощной плов', names)
        self.assertIn('Острая баранина', names)
        self.assertNotIn('Хлеб', names)

    def test_no_duplicates_when_dish_has_multiple_matching_tags(self):
        """Блюдо с несколькими совпавшими тегами не дублируется в результатах."""
        from apps.menu.models import Dish, Category
        category = Category.objects.first()
        dish_both = Dish.objects.create(name='Острый веганский суп', price='1800', category=category)
        dish_both.tags.add(self.tag_vegan, self.tag_spicy)

        response = self.client.get(
            f'/api/v1/menu/dishes/?tag_ids={self.tag_vegan.id},{self.tag_spicy.id}'
        )
        names = [d['name'] for d in response.data['results']]
        # Блюдо с двумя тегами должно появиться ровно один раз
        self.assertEqual(names.count('Острый веганский суп'), 1)


# ---------------------------------------------------------------------------
# Блок 8: working_hours_note — временное изменение режима работы
# ---------------------------------------------------------------------------

class WorkingHoursNoteTest(APITestCase):
    """
    working_hours_note передаётся через GET /api/v1/core/info/.
    Flutter показывает его поверх основного расписания, если не пустое.
    """

    def setUp(self):
        self.info = RestaurantInfo.load()
        self.info.working_hours = 'Пн–Вс: 12:00–00:00'
        self.info.working_hours_note = ''
        self.info.save()

    def test_working_hours_note_present_in_response(self):
        """Поле working_hours_note всегда присутствует в ответе API."""
        response = self.client.get('/api/v1/core/info/')
        self.assertIn('working_hours_note', response.data)

    def test_working_hours_note_empty_by_default(self):
        """По умолчанию поле пустое — нет временных уведомлений."""
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['working_hours_note'], '')

    def test_working_hours_note_reflects_saved_value(self):
        """Если менеджер задал уведомление — оно возвращается приложению."""
        self.info.working_hours_note = 'Закрыто 1 января'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['working_hours_note'], 'Закрыто 1 января')

    def test_working_hours_note_independent_of_working_hours(self):
        """Основные часы работы и временное уведомление — независимые поля."""
        self.info.working_hours = 'Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00'
        self.info.working_hours_note = 'В праздники до 02:00'
        self.info.save()
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['working_hours'], 'Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00')
        self.assertEqual(response.data['working_hours_note'], 'В праздники до 02:00')


# ---------------------------------------------------------------------------
# Блок 8: Контроль доступа к RestaurantInfoAdmin по ролям
# ---------------------------------------------------------------------------

class RestaurantInfoAdminAccessTest(TestCase):
    """
    RestaurantInfoAdmin доступен только content_manager и admin.
    hall_manager и обычный is_staff не должны видеть его.
    """

    def _make_user(self, role):
        from django.contrib.auth import get_user_model
        U = get_user_model()
        u = U.objects.create_user(phone=f'+7700000{abs(hash(role)) % 10000:04d}')
        u.role = role
        u.is_staff = True
        u.save()
        return u

    def setUp(self):
        from .admin import RestaurantInfoAdmin
        from django.contrib.admin import site
        self.admin_class = RestaurantInfoAdmin(RestaurantInfo, site)
        self.info = RestaurantInfo.load()

    def _request(self, user):
        """Фиктивный request-объект с заданным пользователем."""
        from django.test import RequestFactory
        rf = RequestFactory()
        req = rf.get('/')
        req.user = user
        return req

    def test_content_manager_can_view(self):
        user = self._make_user('content_manager')
        self.assertTrue(self.admin_class.has_view_permission(self._request(user)))

    def test_content_manager_can_change(self):
        user = self._make_user('content_manager')
        self.assertTrue(self.admin_class.has_change_permission(self._request(user)))

    def test_hall_manager_cannot_view(self):
        """Менеджер зала не должен иметь доступа к настройкам ресторана."""
        user = self._make_user('hall_manager')
        self.assertFalse(self.admin_class.has_view_permission(self._request(user)))

    def test_admin_role_can_view(self):
        user = self._make_user('admin')
        self.assertTrue(self.admin_class.has_view_permission(self._request(user)))

    def test_delete_always_forbidden(self):
        """Синглтон нельзя удалить ни одной ролью."""
        user = self._make_user('admin')
        self.assertFalse(self.admin_class.has_delete_permission(self._request(user)))


# ---------------------------------------------------------------------------
# Блок 8: Контроль доступа к AppVersionAdmin по ролям
# ---------------------------------------------------------------------------

class AppVersionAdminAccessTest(TestCase):
    """
    AppVersionAdmin доступен только admin (и superuser).
    content_manager и hall_manager не должны иметь доступа.
    """

    def _make_user(self, role):
        from django.contrib.auth import get_user_model
        U = get_user_model()
        u = U.objects.create_user(phone=f'+7800000{abs(hash(role)) % 10000:04d}')
        u.role = role
        u.is_staff = True
        u.save()
        return u

    def setUp(self):
        from .admin import AppVersionAdmin
        from django.contrib.admin import site
        self.admin_class = AppVersionAdmin(AppVersion, site)

    def _request(self, user):
        from django.test import RequestFactory
        rf = RequestFactory()
        req = rf.get('/')
        req.user = user
        return req

    def test_admin_role_can_view(self):
        user = self._make_user('admin')
        self.assertTrue(self.admin_class.has_view_permission(self._request(user)))

    def test_content_manager_cannot_view(self):
        """Контент-менеджер не управляет версиями приложения."""
        user = self._make_user('content_manager')
        self.assertFalse(self.admin_class.has_view_permission(self._request(user)))

    def test_hall_manager_cannot_change(self):
        user = self._make_user('hall_manager')
        self.assertFalse(self.admin_class.has_change_permission(self._request(user)))


# =============================================================================
# seed_initial_data — management command
# =============================================================================

class SeedInitialDataCommandTest(TestCase):
    """Команда создаёт все нужные записи на пустой базе."""

    def test_creates_restaurant_info(self):
        """После выполнения команды RestaurantInfo существует и адрес заполнен."""
        from django.core.management import call_command

        # Убеждаемся, что синглтон ещё не создан
        RestaurantInfo.objects.all().delete()

        call_command("seed_initial_data", verbosity=0)

        info = RestaurantInfo.load()
        self.assertTrue(info.address)
        self.assertTrue(info.working_hours)

    def test_creates_app_versions_for_both_platforms(self):
        """После выполнения команды существуют записи для ios и android."""
        from django.core.management import call_command

        AppVersion.objects.all().delete()

        call_command("seed_initial_data", verbosity=0)

        self.assertTrue(AppVersion.objects.filter(platform="ios").exists())
        self.assertTrue(AppVersion.objects.filter(platform="android").exists())

    def test_initial_versions_are_1_0_0(self):
        """Версия по умолчанию — 1.0.0."""
        from django.core.management import call_command

        AppVersion.objects.all().delete()
        call_command("seed_initial_data", verbosity=0)

        ios = AppVersion.objects.get(platform="ios")
        self.assertEqual(ios.min_version, "1.0.0")
        self.assertEqual(ios.latest_version, "1.0.0")


class SeedInitialDataIdempotentTest(TestCase):
    """Повторный запуск без --force не создаёт дублей и не затирает данные."""

    def setUp(self):
        from django.core.management import call_command
        call_command("seed_initial_data", verbosity=0)

    def test_no_duplicate_app_versions(self):
        """После двух запусков кряду количество AppVersion остаётся равным 2."""
        from django.core.management import call_command
        call_command("seed_initial_data", verbosity=0)
        self.assertEqual(AppVersion.objects.count(), 2)

    def test_existing_address_not_overwritten(self):
        """Без --force команда не затирает данные, изменённые администратором."""
        from django.core.management import call_command

        info = RestaurantInfo.load()
        info.address = "Кастомный адрес"
        info.save()

        call_command("seed_initial_data", verbosity=0)

        info.refresh_from_db()
        self.assertEqual(info.address, "Кастомный адрес")


class SeedInitialDataForceTest(TestCase):
    """Флаг --force перезаписывает существующие записи."""

    def setUp(self):
        from django.core.management import call_command
        call_command("seed_initial_data", verbosity=0)

    def test_force_resets_app_version(self):
        """--force сбрасывает версии к 1.0.0 даже если они были изменены."""
        from django.core.management import call_command

        ios = AppVersion.objects.get(platform="ios")
        ios.min_version = "2.5.0"
        ios.latest_version = "3.0.0"
        ios.save()

        call_command("seed_initial_data", "--force", verbosity=0)

        ios.refresh_from_db()
        self.assertEqual(ios.min_version, "1.0.0")
        self.assertEqual(ios.latest_version, "1.0.0")

    def test_force_still_no_duplicates(self):
        """--force не создаёт новых записей AppVersion."""
        from django.core.management import call_command
        call_command("seed_initial_data", "--force", verbosity=0)
        self.assertEqual(AppVersion.objects.count(), 2)


# =============================================================================
# GET /api/v1/health/ — проверка работоспособности сервисов
# =============================================================================

class HealthCheckOkTest(APITestCase):
    """Все сервисы доступны — эндпоинт возвращает 200 и status=ok."""

    def test_returns_200_when_all_ok(self):
        response = self.client.get('/api/v1/core/health/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'ok')
        self.assertEqual(response.data['db'], 'ok')

    def test_no_auth_required(self):
        """Эндпоинт доступен без авторизации — нужен для мониторинга."""
        response = self.client.get('/api/v1/core/health/')
        # Не должен вернуть 401 или 403
        self.assertNotEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertNotEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_response_contains_required_keys(self):
        """Ответ содержит ключи status, db, redis."""
        response = self.client.get('/api/v1/core/health/')
        for key in ('status', 'db', 'redis'):
            self.assertIn(key, response.data)


class HealthCheckRedisDownTest(APITestCase):
    """При недоступном Redis возвращается 503 и status=degraded."""

    @patch('apps.core.health.cache')
    def test_returns_503_when_redis_down(self, mock_cache):
        # Симулируем сбой Redis
        mock_cache.set.side_effect = Exception("Connection refused")

        response = self.client.get('/api/v1/core/health/')

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(response.data['status'], 'degraded')
        self.assertEqual(response.data['redis'], 'error')
        # БД при этом должна быть ok
        self.assertEqual(response.data['db'], 'ok')


# =============================================================================
# Кэширование: RestaurantInfo
# =============================================================================

class RestaurantInfoCacheTest(APITestCase):
    """Проверяем, что RestaurantInfo кэшируется и инвалидируется через сигнал."""

    def setUp(self):
        cache.clear()
        self.info = RestaurantInfo.load()
        self.info.address = 'Исходный адрес'
        self.info.save()

    def tearDown(self):
        cache.clear()

    def test_cache_miss_populates_cache(self):
        """Первый запрос записывает данные в кэш."""
        self.assertIsNone(cache.get('restaurant_info'))
        self.client.get('/api/v1/core/info/')
        self.assertIsNotNone(cache.get('restaurant_info'))

    def test_second_request_uses_cache(self):
        """Второй запрос возвращает данные из кэша без обращения к RestaurantInfo.load."""
        with patch.object(RestaurantInfo, 'load', wraps=RestaurantInfo.load) as mock_load:
            self.client.get('/api/v1/core/info/')  # промах — вызывает load
            self.client.get('/api/v1/core/info/')  # попадание — load не вызывается
            self.assertEqual(mock_load.call_count, 1)

    def test_post_save_invalidates_cache(self):
        """Сохранение синглтона сбрасывает кэш — следующий запрос читает свежие данные."""
        self.client.get('/api/v1/core/info/')           # наполнить кэш
        self.info.address = 'Новый адрес'
        self.info.save()                                # инвалидация через сигнал
        self.assertIsNone(cache.get('restaurant_info'))
        response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.data['address'], 'Новый адрес')


# =============================================================================
# Кэширование: InteriorPhoto
# =============================================================================

class InteriorPhotoCacheTest(APITestCase):
    """Проверяем кэш галереи интерьера."""

    def setUp(self):
        cache.clear()
        InteriorPhoto.objects.create(zone='main_hall', order=1, caption='Вид 1')
        InteriorPhoto.objects.create(zone='bar', order=1, caption='Бар')

    def tearDown(self):
        cache.clear()

    def test_cache_miss_populates_cache(self):
        """Первый запрос записывает список фотографий в кэш."""
        self.assertIsNone(cache.get('interior_photos'))
        self.client.get('/api/v1/core/interior/')
        self.assertIsNotNone(cache.get('interior_photos'))

    def test_post_save_invalidates_cache(self):
        """Добавление новой фотографии инвалидирует кэш."""
        self.client.get('/api/v1/core/interior/')
        self.assertIsNotNone(cache.get('interior_photos'))
        InteriorPhoto.objects.create(zone='terrace', order=1, caption='Терраса')
        self.assertIsNone(cache.get('interior_photos'))
        response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(len(response.data), 3)

    def test_post_delete_invalidates_cache(self):
        """Удаление фотографии инвалидирует кэш."""
        self.client.get('/api/v1/core/interior/')
        InteriorPhoto.objects.first().delete()
        self.assertIsNone(cache.get('interior_photos'))
        response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(len(response.data), 1)


# ---------------------------------------------------------------------------
# Устойчивость к падению Redis (fallback к БД)
# ---------------------------------------------------------------------------

class CoreRedisResilienceTest(APITestCase):
    """Проверяет что core-эндпоинты доступны при недоступном Redis."""

    def setUp(self):
        cache.clear()
        RestaurantInfo.objects.create(
            address='ул. Панфилова, 98',
            working_hours='12:00–00:00',
        )

    def test_restaurant_info_works_when_redis_unavailable(self):
        """GET /api/v1/core/info/ должен вернуть 200 даже если Redis недоступен."""
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get_or_set.side_effect = Exception("Redis down")
            response = self.client.get('/api/v1/core/info/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['address'], 'ул. Панфилова, 98')

    def test_interior_photos_works_when_redis_unavailable(self):
        """GET /api/v1/core/interior/ должен вернуть 200 даже если Redis недоступен."""
        InteriorPhoto.objects.create(zone='main_hall', order=1)
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.return_value = None
            mock_cache.set.side_effect = Exception("Redis down")
            response = self.client.get('/api/v1/core/interior/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

from unittest.mock import MagicMock, patch

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

import sys
from unittest.mock import MagicMock as _MagicMock

from .models import Category, Dish, Tag, Allergen

# ffmpeg доступен только внутри Docker-образа (собранного с ffmpeg-python).
# Заглушаем его здесь, чтобы apps.menu.tasks импортировался без нативного бинарника.
if 'ffmpeg' not in sys.modules:
    sys.modules['ffmpeg'] = _MagicMock()
import apps.menu.tasks  # noqa: F401 — гарантирует наличие модуля в sys.modules для @patch

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
        response = self.client.get('/api/v1/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        orders = [c['order'] for c in response.data]
        self.assertEqual(orders, sorted(orders))

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_returns_all_categories_without_pagination(self):
        for i in range(25):
            Category.objects.create(name=f'Кат {i}', order=i)
        response = self.client.get('/api/v1/menu/categories/')
        # No pagination — all items in a plain list
        self.assertIsInstance(response.data, list)
        self.assertEqual(len(response.data), 25)

    def test_empty_list_returns_200(self):
        response = self.client.get('/api/v1/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])

    def test_response_contains_required_fields(self):
        Category.objects.create(name='Десерты', order=5)
        response = self.client.get('/api/v1/menu/categories/')
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
        response = self.client.get('/api/v1/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertIn('Греческий салат', names)
        self.assertNotIn('Скрытое блюдо', names)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_filter_by_category_id(self):
        response = self.client.get(f'/api/v1/menu/dishes/?category_id={self.cat1.pk}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertNotIn('Греческий салат', names)

    def test_filter_by_tag_ids(self):
        # Параметр переименован с tag_id → tag_ids (поддерживает несколько через запятую)
        response = self.client.get(f'/api/v1/menu/dishes/?tag_ids={self.tag.pk}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Стейк', names)
        self.assertNotIn('Греческий салат', names)

    def test_default_page_size_is_5(self):
        cat = make_category('Большая', order=10)
        for i in range(10):
            make_dish(cat, name=f'Блюдо {i}')
        response = self.client.get('/api/v1/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(response.data['results']), 5)

    def test_response_contains_nested_category(self):
        response = self.client.get(f'/api/v1/menu/dishes/?category_id={self.cat1.pk}')
        dish = response.data['results'][0]
        self.assertIn('category', dish)
        self.assertEqual(dish['category']['id'], self.cat1.pk)

    def test_response_contains_tags_and_allergens(self):
        response = self.client.get(f'/api/v1/menu/dishes/?category_id={self.cat2.pk}')
        dish = response.data['results'][0]
        self.assertIn('tags', dish)
        self.assertIn('allergens', dish)
        allergen_names = [a['name'] for a in dish['allergens']]
        self.assertIn('Глютен', allergen_names)

    def test_pagination_next_link_present_when_more_items(self):
        cat = make_category('Огромная', order=20)
        for i in range(6):
            make_dish(cat, name=f'Доп {i}')
        response = self.client.get(f'/api/v1/menu/dishes/?category_id={cat.pk}')
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


# =============================================================================
# Кэширование: CategoryListView
# =============================================================================

class CategoryCacheTest(APITestCase):
    """Кэш категорий: наполнение, попадание и инвалидация через сигнал."""

    def setUp(self):
        cache.clear()
        Category.objects.create(name='Горячие', order=1)
        Category.objects.create(name='Напитки', order=2)

    def tearDown(self):
        cache.clear()

    def test_cache_miss_populates_cache(self):
        """Первый запрос записывает список категорий в кэш."""
        self.assertIsNone(cache.get('menu_categories'))
        self.client.get('/api/v1/menu/categories/')
        self.assertIsNotNone(cache.get('menu_categories'))

    def test_cache_hit_returns_same_data(self):
        """Второй запрос возвращает те же данные из кэша."""
        r1 = self.client.get('/api/v1/menu/categories/')
        r2 = self.client.get('/api/v1/menu/categories/')
        self.assertEqual(r1.data, r2.data)

    def test_post_save_invalidates_cache(self):
        """Создание новой категории инвалидирует кэш."""
        self.client.get('/api/v1/menu/categories/')
        Category.objects.create(name='Десерты', order=3)
        self.assertIsNone(cache.get('menu_categories'))
        response = self.client.get('/api/v1/menu/categories/')
        names = [c['name'] for c in response.data]
        self.assertIn('Десерты', names)

    def test_post_delete_invalidates_cache(self):
        """Удаление категории инвалидирует кэш."""
        self.client.get('/api/v1/menu/categories/')
        Category.objects.filter(name='Напитки').delete()
        self.assertIsNone(cache.get('menu_categories'))
        response = self.client.get('/api/v1/menu/categories/')
        names = [c['name'] for c in response.data]
        self.assertNotIn('Напитки', names)


# =============================================================================
# Кэширование: DishListView (версионный кэш)
# =============================================================================

class DishCacheTest(APITestCase):
    """Версионный кэш блюд: наполнение, попадание и инвалидация."""

    def setUp(self):
        cache.clear()
        self.cat = make_category('Горячие', order=1)
        make_dish(self.cat, name='Стейк')

    def tearDown(self):
        cache.clear()

    def _get_cache_version(self):
        return cache.get('menu_dishes_cache_version', 1)

    def test_cache_hit_on_second_request(self):
        """Второй запрос с теми же параметрами должен попасть в кэш."""
        r1 = self.client.get('/api/v1/menu/dishes/')
        version   = self._get_cache_version()
        cache_key = f'menu_dishes:{version}:'
        self.assertIsNotNone(cache.get(cache_key))
        r2 = self.client.get('/api/v1/menu/dishes/')
        self.assertEqual(r1.data, r2.data)

    def test_post_save_dish_bumps_version(self):
        """Сохранение блюда инкрементирует версию кэша."""
        self.client.get('/api/v1/menu/dishes/')
        v_before = self._get_cache_version()
        make_dish(self.cat, name='Суп')
        v_after = self._get_cache_version()
        self.assertEqual(v_after, v_before + 1)

    def test_after_invalidation_new_dish_appears(self):
        """После инвалидации новое блюдо возвращается в ответе."""
        self.client.get('/api/v1/menu/dishes/')
        make_dish(self.cat, name='Новинка')
        response = self.client.get('/api/v1/menu/dishes/')
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Новинка', names)

    def test_category_change_bumps_dishes_version(self):
        """Изменение категории также инкрементирует версию кэша блюд."""
        self.client.get('/api/v1/menu/dishes/')
        v_before = self._get_cache_version()
        self.cat.name = 'Переименовано'
        self.cat.save()
        self.assertGreater(self._get_cache_version(), v_before)

    def test_different_query_params_have_separate_cache_entries(self):
        """Запросы с разными параметрами кэшируются отдельно."""
        cat2 = make_category('Салаты', order=2)
        make_dish(cat2, name='Цезарь')
        r_all = self.client.get('/api/v1/menu/dishes/')
        r_filtered = self.client.get(f'/api/v1/menu/dishes/?category_id={cat2.pk}')
        # Общий список и отфильтрованный — разные наборы блюд
        names_all = [d['name'] for d in r_all.data['results']]
        names_filtered = [d['name'] for d in r_filtered.data['results']]
        self.assertIn('Стейк', names_all)
        self.assertNotIn('Стейк', names_filtered)


# ---------------------------------------------------------------------------
# Устойчивость к падению Redis (fallback к БД)
# ---------------------------------------------------------------------------

class MenuRedisResilienceTest(APITestCase):
    """Проверяет что меню доступно даже при недоступном Redis."""

    def setUp(self):
        cache.clear()
        self.cat = Category.objects.create(name='Основное', order=1)
        make_dish(self.cat, name='Борщ')

    def test_category_list_works_when_redis_unavailable(self):
        """GET /api/v1/menu/categories/ должен вернуть 200 даже если Redis недоступен."""
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.side_effect = Exception("Redis down")
            mock_cache.set.side_effect = Exception("Redis down")
            response = self.client.get('/api/v1/menu/categories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_dish_list_works_when_redis_unavailable(self):
        """GET /api/v1/menu/dishes/ должен вернуть 200 даже если Redis недоступен."""
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.return_value = None
            mock_cache.set.side_effect = Exception("Redis down")
            response = self.client.get('/api/v1/menu/dishes/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


# =============================================================================
# Вспомогательная фабрика для видео
# =============================================================================

def make_fake_video(name='test.mp4'):
    return SimpleUploadedFile(name, b'fake-video-bytes', content_type='video/mp4')


def make_ready_dish(category, name='Видео-блюдо'):
    """Создаёт активное блюдо с video_status=READY через .update() (без сигнала)."""
    dish = make_dish(category, name=name)
    Dish.objects.filter(pk=dish.pk).update(video_status=Dish.VideoStatus.READY)
    dish.refresh_from_db()
    return dish


# =============================================================================
# GET /api/v1/menu/feed/ — VideoFeedView
# =============================================================================

class VideoFeedViewTest(APITestCase):
    """Курсорная видеолента: только активные блюда со статусом READY."""

    def setUp(self):
        self.cat = make_category()
        self.dish_ready_1 = make_ready_dish(self.cat, name='Готовое 1')
        self.dish_ready_2 = make_ready_dish(self.cat, name='Готовое 2')
        # PENDING — не должно попасть в ленту
        self.dish_pending = make_dish(self.cat, name='Ожидает')
        # READY + inactive — не должно попасть в ленту
        self.dish_inactive = make_dish(self.cat, name='Неактивное', is_active=False)
        Dish.objects.filter(pk=self.dish_inactive.pk).update(video_status=Dish.VideoStatus.READY)

    def test_returns_only_ready_active_dishes(self):
        response = self.client.get('/api/v1/menu/feed/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [d['name'] for d in response.data['results']]
        self.assertIn('Готовое 1', names)
        self.assertIn('Готовое 2', names)

    def test_excludes_pending_dishes(self):
        response = self.client.get('/api/v1/menu/feed/')
        names = [d['name'] for d in response.data['results']]
        self.assertNotIn('Ожидает', names)

    def test_excludes_inactive_dishes(self):
        response = self.client.get('/api/v1/menu/feed/')
        names = [d['name'] for d in response.data['results']]
        self.assertNotIn('Неактивное', names)

    def test_public_access_no_auth_required(self):
        response = self.client.get('/api/v1/menu/feed/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_response_has_cursor_pagination_envelope(self):
        response = self.client.get('/api/v1/menu/feed/')
        for key in ('results', 'next', 'previous'):
            self.assertIn(key, response.data)

    def test_cursor_next_present_when_more_than_page_size(self):
        for i in range(5):
            make_ready_dish(self.cat, name=f'Доп {i}')
        response = self.client.get('/api/v1/menu/feed/')
        # 2 from setUp + 5 новых = 7 > page_size(5)
        self.assertIsNotNone(response.data.get('next'))

    def test_cursor_navigation_reaches_second_page(self):
        for i in range(5):
            make_ready_dish(self.cat, name=f'Стр2 {i}')
        r1 = self.client.get('/api/v1/menu/feed/')
        next_url = r1.data['next']
        self.assertIsNotNone(next_url)
        from urllib.parse import parse_qs, urlparse
        cursor = parse_qs(urlparse(next_url).query)['cursor'][0]
        r2 = self.client.get(f'/api/v1/menu/feed/?cursor={cursor}')
        self.assertEqual(r2.status_code, status.HTTP_200_OK)
        self.assertGreater(len(r2.data['results']), 0)

    def test_no_duplicate_items_across_pages(self):
        for i in range(8):
            make_ready_dish(self.cat, name=f'Уник {i}')
        r1 = self.client.get('/api/v1/menu/feed/')
        from urllib.parse import parse_qs, urlparse
        cursor = parse_qs(urlparse(r1.data['next']).query)['cursor'][0]
        r2 = self.client.get(f'/api/v1/menu/feed/?cursor={cursor}')
        ids_p1 = {d['id'] for d in r1.data['results']}
        ids_p2 = {d['id'] for d in r2.data['results']}
        self.assertFalse(ids_p1 & ids_p2, "Дублирование блюд между страницами курсора")

    def test_video_status_field_present_in_results(self):
        response = self.client.get('/api/v1/menu/feed/')
        if response.data['results']:
            self.assertIn('video_status', response.data['results'][0])


# =============================================================================
# DishSerializer: поля video_url и video_status
# =============================================================================

class DishSerializerVideoFieldsTest(APITestCase):
    """video_url и video_status в ответах DishListView и VideoFeedView."""

    def setUp(self):
        self.cat = make_category()

    def test_video_url_is_none_when_no_processed_video(self):
        make_dish(self.cat, name='Без видео')
        response = self.client.get('/api/v1/menu/dishes/')
        dish = response.data['results'][0]
        self.assertIn('video_url', dish)
        self.assertIsNone(dish['video_url'])

    def test_video_status_present_in_dish_list(self):
        make_dish(self.cat, name='Тест статуса')
        response = self.client.get('/api/v1/menu/dishes/')
        dish = response.data['results'][0]
        self.assertIn('video_status', dish)

    def test_new_dish_has_pending_status(self):
        make_dish(self.cat, name='Новое блюдо')
        response = self.client.get('/api/v1/menu/dishes/')
        dish = response.data['results'][0]
        self.assertEqual(dish['video_status'], Dish.VideoStatus.PENDING)

    def test_ready_status_reflected_in_response(self):
        dish = make_ready_dish(self.cat, name='Готовое')
        response = self.client.get(f'/api/v1/menu/dishes/?category_id={self.cat.pk}')
        result = next(d for d in response.data['results'] if d['id'] == dish.pk)
        self.assertEqual(result['video_status'], Dish.VideoStatus.READY)


# =============================================================================
# Сигнал trigger_video_processing
# =============================================================================

class TriggerVideoProcessingSignalTest(TestCase):
    """post_save сигнал ставит задачу транскодирования в очередь при нужных условиях."""

    def setUp(self):
        self.cat = make_category()

    @patch('apps.menu.tasks.process_dish_video')
    def test_task_queued_when_dish_with_video_saved_as_pending(self, mock_task):
        dish = make_dish(self.cat, name='С видео')
        mock_task.delay.reset_mock()
        dish.video = make_fake_video()
        dish.video_status = Dish.VideoStatus.PENDING
        dish.save(update_fields=['video', 'video_status'])
        mock_task.delay.assert_called_once_with(dish.pk)

    @patch('apps.menu.tasks.process_dish_video')
    def test_task_queued_when_status_is_failed(self, mock_task):
        dish = make_dish(self.cat, name='Упавшее')
        mock_task.delay.reset_mock()
        dish.video = make_fake_video()
        dish.video_status = Dish.VideoStatus.FAILED
        dish.save(update_fields=['video', 'video_status'])
        mock_task.delay.assert_called_once_with(dish.pk)

    @patch('apps.menu.tasks.process_dish_video')
    def test_task_not_queued_when_no_video(self, mock_task):
        make_dish(self.cat, name='Без видео')
        mock_task.delay.assert_not_called()

    @patch('apps.menu.tasks.process_dish_video')
    def test_task_not_queued_when_status_is_ready(self, mock_task):
        dish = make_dish(self.cat, name='Уже готово')
        mock_task.delay.reset_mock()
        dish.video = make_fake_video()
        dish.video_status = Dish.VideoStatus.READY
        dish.save(update_fields=['video', 'video_status'])
        mock_task.delay.assert_not_called()

    @patch('apps.menu.tasks.process_dish_video')
    def test_task_not_queued_when_status_is_processing(self, mock_task):
        dish = make_dish(self.cat, name='В обработке')
        mock_task.delay.reset_mock()
        dish.video = make_fake_video()
        dish.video_status = Dish.VideoStatus.PROCESSING
        dish.save(update_fields=['video', 'video_status'])
        mock_task.delay.assert_not_called()


# =============================================================================
# Celery-задача process_dish_video
# =============================================================================

class ProcessDishVideoTaskTest(TestCase):
    """Задача транскодирования: успех, ошибка FFmpeg, отсутствующее блюдо."""

    def setUp(self):
        self.cat = make_category()
        self.dish = make_dish(self.cat, name='Видеоблюдо')
        # Назначаем путь к видео через .update() чтобы не дёргать сигнал повторно
        Dish.objects.filter(pk=self.dish.pk).update(video='dishes/videos/fake.mp4')
        self.dish.refresh_from_db()

    def test_handles_nonexistent_dish_silently(self):
        from .tasks import process_dish_video
        result = process_dish_video.apply(args=[99999]).get()
        self.assertIsNone(result)

    @patch('apps.menu.tasks.ffmpeg')
    @patch('apps.menu.tasks.os.unlink')
    @patch('apps.menu.tasks.tempfile.NamedTemporaryFile')
    @patch('builtins.open')
    def test_sets_ready_status_on_success(self, mock_open, mock_tmp, mock_unlink, mock_ffmpeg):
        mock_ffmpeg.input.return_value.output.return_value.run.return_value = (b'', b'')

        mock_tmp_ctx = MagicMock()
        mock_tmp_ctx.name = '/tmp/fake_out.mp4'
        mock_tmp.return_value.__enter__ = lambda s: mock_tmp_ctx
        mock_tmp.return_value.__exit__ = MagicMock(return_value=False)

        from unittest.mock import PropertyMock
        # Dish импортируется внутри тела задачи, поэтому патчим через apps.menu.models
        with patch.object(type(self.dish.video), 'path', new_callable=PropertyMock,
                          return_value='/fake/src.mp4'):
            with patch.object(self.dish.video_processed, 'save'):
                with patch('apps.menu.models.Dish.objects.get', return_value=self.dish):
                    from .tasks import process_dish_video
                    process_dish_video.apply(args=[self.dish.pk]).get()

        self.dish.refresh_from_db()
        self.assertEqual(self.dish.video_status, Dish.VideoStatus.READY)

    @patch('apps.menu.tasks.ffmpeg')
    @patch('apps.menu.tasks.os.unlink')
    @patch('apps.menu.tasks.tempfile.NamedTemporaryFile')
    def test_sets_failed_status_on_ffmpeg_error(self, mock_tmp, mock_unlink, mock_ffmpeg):
        # Создаём собственный класс ошибки, так как ffmpeg заглушён MagicMock-ом
        class FakeFFmpegError(Exception):
            def __init__(self, cmd, stdout, stderr):
                self.stderr = stderr

        mock_tmp_ctx = MagicMock()
        mock_tmp_ctx.name = '/tmp/fake_out.mp4'
        mock_tmp.return_value.__enter__ = lambda s: mock_tmp_ctx
        mock_tmp.return_value.__exit__ = MagicMock(return_value=False)

        mock_ffmpeg.Error = FakeFFmpegError
        mock_ffmpeg.input.return_value.output.return_value.run.side_effect = (
            FakeFFmpegError('ffmpeg', b'', b'encoding failed')
        )

        from unittest.mock import PropertyMock
        # Dish импортируется внутри тела задачи, поэтому патчим через apps.menu.models
        with patch.object(type(self.dish.video), 'path', new_callable=PropertyMock,
                          return_value='/fake/src.mp4'):
            with patch('apps.menu.models.Dish.objects.get', return_value=self.dish):
                from .tasks import process_dish_video
                # max_retries=2; apply() при Retry поднимает исключение — перехватываем
                try:
                    process_dish_video.apply(args=[self.dish.pk]).get()
                except Exception:
                    pass

        self.dish.refresh_from_db()
        self.assertEqual(self.dish.video_status, Dish.VideoStatus.FAILED)

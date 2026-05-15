from unittest.mock import patch

from django.test import TestCase

from utils.cache import (
    safe_cache_add,
    safe_cache_delete,
    safe_cache_get,
    safe_cache_get_or_set,
    safe_cache_set,
)


class SafeCacheGetTest(TestCase):
    def test_returns_value_when_redis_available(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.return_value = 'hello'
            result = safe_cache_get('key')
        self.assertEqual(result, 'hello')

    def test_returns_default_when_redis_raises(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.side_effect = Exception("Connection refused")
            result = safe_cache_get('key', default='fallback')
        self.assertEqual(result, 'fallback')

    def test_returns_none_when_redis_raises_and_no_default(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get.side_effect = Exception("Connection refused")
            result = safe_cache_get('key')
        self.assertIsNone(result)


class SafeCacheSetTest(TestCase):
    def test_sets_value_when_redis_available(self):
        with patch('utils.cache.cache') as mock_cache:
            safe_cache_set('key', 'value', timeout=60)
            mock_cache.set.assert_called_once_with('key', 'value', timeout=60)

    def test_does_not_raise_when_redis_unavailable(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.set.side_effect = Exception("Connection refused")
            safe_cache_set('key', 'value')  # должен не упасть


class SafeCacheDeleteTest(TestCase):
    def test_deletes_when_redis_available(self):
        with patch('utils.cache.cache') as mock_cache:
            safe_cache_delete('key')
            mock_cache.delete.assert_called_once_with('key')

    def test_does_not_raise_when_redis_unavailable(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.delete.side_effect = Exception("Connection refused")
            safe_cache_delete('key')  # должен не упасть


class SafeCacheGetOrSetTest(TestCase):
    def test_returns_cached_value_when_available(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get_or_set.return_value = 'cached'
            result = safe_cache_get_or_set('key', lambda: 'computed')
        self.assertEqual(result, 'cached')

    def test_calls_fallback_fn_when_redis_raises(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get_or_set.side_effect = Exception("Connection refused")
            result = safe_cache_get_or_set('key', lambda: 'computed_fallback')
        self.assertEqual(result, 'computed_fallback')

    def test_returns_non_callable_default_when_redis_raises(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.get_or_set.side_effect = Exception("Connection refused")
            result = safe_cache_get_or_set('key', 'static_default')
        self.assertEqual(result, 'static_default')


class SafeCacheAddTest(TestCase):
    def test_returns_cache_result_when_available(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.add.return_value = False
            result = safe_cache_add('key', True)
        self.assertFalse(result)

    def test_returns_true_when_redis_raises(self):
        with patch('utils.cache.cache') as mock_cache:
            mock_cache.add.side_effect = Exception("Connection refused")
            result = safe_cache_add('key', True)
        self.assertTrue(result)

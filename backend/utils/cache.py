import logging
from django.core.cache import cache

logger = logging.getLogger(__name__)

_CACHE_UNAVAILABLE = "Redis unavailable"


def safe_cache_get(key, default=None):
    """
    cache.get с graceful degradation: при недоступном Redis возвращает default
    вместо того чтобы бросить исключение и уронить запрос.
    """
    try:
        return cache.get(key, default)
    except Exception:
        logger.warning("%s — cache.get(%s) skipped", _CACHE_UNAVAILABLE, key)
        return default


def safe_cache_set(key, value, timeout=None):
    """
    cache.set с graceful degradation: при недоступном Redis логирует WARNING
    и продолжает работу без кэширования.
    """
    try:
        cache.set(key, value, timeout=timeout)
    except Exception:
        logger.warning("%s — cache.set(%s) skipped", _CACHE_UNAVAILABLE, key)


def safe_cache_delete(key):
    try:
        cache.delete(key)
    except Exception:
        logger.warning("%s — cache.delete(%s) skipped", _CACHE_UNAVAILABLE, key)


def safe_cache_get_or_set(key, default_fn, timeout=None):
    """
    Аналог cache.get_or_set, но при ошибке Redis вызывает default_fn напрямую
    без попытки записи в кэш.
    """
    try:
        return cache.get_or_set(key, default_fn, timeout=timeout)
    except Exception:
        logger.warning("%s — cache.get_or_set(%s) skipped, calling fallback", _CACHE_UNAVAILABLE, key)
        return default_fn() if callable(default_fn) else default_fn


def safe_cache_add(key, value, timeout=None):
    """
    cache.add с graceful degradation. Возвращает True (как будто ключ добавлен),
    чтобы caller мог продолжать работу при недоступном Redis.
    """
    try:
        return cache.add(key, value, timeout=timeout)
    except Exception:
        logger.warning("%s — cache.add(%s) skipped, returning True", _CACHE_UNAVAILABLE, key)
        return True

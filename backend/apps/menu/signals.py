from django.core.cache import cache
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .models import Allergen, Category, Dish, Tag


def _bump_dishes_version():
    """
    Инкрементирует счётчик версии кэша блюд.
    Все ключи вида 'menu_dishes:{старая_версия}:...' перестают использоваться
    и истекут по TTL самостоятельно.
    """
    v = cache.get('menu_dishes_cache_version', 0)
    cache.set('menu_dishes_cache_version', v + 1, timeout=None)


@receiver([post_save, post_delete], sender=Category)
def invalidate_on_category_change(sender, **kwargs):
    """Сбрасывает кэш категорий и версию кэша блюд при изменении категории."""
    cache.delete('menu_categories')
    _bump_dishes_version()


@receiver([post_save, post_delete], sender=Dish)
def invalidate_on_dish_change(sender, **kwargs):
    """Инкрементирует версию кэша блюд при добавлении/изменении/удалении блюда."""
    _bump_dishes_version()


@receiver([post_save, post_delete], sender=Tag)
@receiver([post_save, post_delete], sender=Allergen)
def invalidate_on_related_change(sender, **kwargs):
    """Инкрементирует версию кэша блюд при изменении тегов или аллергенов."""
    _bump_dishes_version()

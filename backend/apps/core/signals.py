from django.core.cache import cache
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .models import InteriorPhoto, RestaurantInfo
from utils.cache import safe_cache_delete


@receiver([post_save, post_delete], sender=RestaurantInfo)
def invalidate_restaurant_info_cache(sender, **kwargs):
    """Сбрасывает кэш синглтона при любом изменении через Django admin."""
    safe_cache_delete('restaurant_info')


@receiver([post_save, post_delete], sender=InteriorPhoto)
def invalidate_interior_photos_cache(sender, **kwargs):
    """Сбрасывает кэш галереи интерьера при добавлении/изменении/удалении фото."""
    safe_cache_delete('interior_photos')

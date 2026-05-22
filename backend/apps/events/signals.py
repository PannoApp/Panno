import logging
from django.core.cache import cache
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .models import Event, EventReservation, News
from utils.cache import safe_cache_get, safe_cache_set

from django.utils import timezone

logger = logging.getLogger(__name__)


def _bump_events_version(prefix: str):
    """Инкрементирует счётчик версии кэша для указанного префикса (upcoming/archived/news)."""
    key = f'events_{prefix}_cache_version'
    v = safe_cache_get(key, 0)
    safe_cache_set(key, v + 1, timeout=None)


@receiver([post_save, post_delete], sender=Event)
def invalidate_events_cache(sender, **kwargs):
    """Сбрасывает кэш предстоящих и прошедших событий при изменении любого Event."""
    _bump_events_version('upcoming')
    _bump_events_version('archived')


@receiver([post_save, post_delete], sender=News)
def invalidate_news_cache(sender, **kwargs):
    """Сбрасывает кэш новостей при добавлении/изменении/удалении новости."""
    _bump_events_version('news')


@receiver(post_save, sender=EventReservation)
def notify_on_reservation_created(sender, instance, created, **kwargs):
    if not created:
        return

    event = instance.event
    title = "Вы записаны на мероприятие"
    local_dt = timezone.localtime(event.date_time)
    body = f"{event.title} — {local_dt.strftime('%d.%m.%Y %H:%M')}"

    from apps.notifications.tasks import send_push_notification
    try:
        send_push_notification.delay(
            user_id=instance.user_id,
            title=title,
            body=body,
            data={'event_id': str(event.pk), 'reservation_id': str(instance.pk)},
        )
        logger.info("Push queued: reservation=%s event=%s user=%s", instance.pk, event.pk, instance.user_id)
    except Exception:
        logger.error(
            "Celery broker unavailable — push for reservation=%s not queued", instance.pk
        )

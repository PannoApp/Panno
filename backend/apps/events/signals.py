import logging
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import EventReservation

logger = logging.getLogger(__name__)


@receiver(post_save, sender=EventReservation)
def notify_on_reservation_created(sender, instance, created, **kwargs):
    if not created:
        return

    event = instance.event
    title = "Вы записаны на мероприятие"
    body = f"{event.title} — {event.date_time.strftime('%d.%m.%Y %H:%M')}"

    from apps.notifications.tasks import send_push_notification
    send_push_notification.delay(
        user_id=instance.user_id,
        title=title,
        body=body,
        data={'event_id': str(event.pk), 'reservation_id': str(instance.pk)},
    )
    logger.info("Push queued: reservation=%s event=%s user=%s", instance.pk, event.pk, instance.user_id)

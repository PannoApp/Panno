import logging
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import TableBooking

logger = logging.getLogger(__name__)

_STATUS_PUSH = {
    'confirmed': (
        "Бронирование подтверждено",
        "Ваш столик забронирован. Ждём вас!",
    ),
    'canceled': (
        "Бронирование отменено",
        "Ваше бронирование было отменено.",
    ),
    'completed': (
        "Спасибо за визит!",
        "Рады были вас видеть. Ждём снова!",
    ),
}


@receiver(post_save, sender=TableBooking)
def notify_on_status_change(sender, instance, created, **kwargs):
    from apps.notifications.tasks import send_push_notification

    if not instance.user_id:
        return

    if created:
        send_push_notification.delay(
            user_id=instance.user_id,
            title="Заявка принята",
            body="Мы свяжемся с вами в ближайшее время.",
            data={'booking_id': str(instance.pk), 'status': 'pending'},
        )
        logger.info("Push queued: booking=%s created", instance.pk)
        return

    old_status = getattr(instance, '_original_status', None)
    if old_status == instance.status:
        return

    push = _STATUS_PUSH.get(instance.status)
    if not push:
        return

    title, body = push

    send_push_notification.delay(
        user_id=instance.user_id,
        title=title,
        body=body,
        data={'booking_id': str(instance.pk), 'status': instance.status},
    )
    logger.info("Push queued: booking=%s status=%s→%s", instance.pk, old_status, instance.status)

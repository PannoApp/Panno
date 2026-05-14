import logging
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import TableBooking

logger = logging.getLogger(__name__)

# Статические тексты для статусов без подстановки переменных
_STATUS_PUSH = {
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

    if created:
        if instance.user_id:
            send_push_notification.delay(
                user_id=instance.user_id,
                title="Заявка принята",
                body="Мы свяжемся с вами в ближайшее время.",
                data={'booking_id': str(instance.pk), 'status': 'pending'},
            )
        from apps.bookings.tasks import send_telegram_notification
        send_telegram_notification.delay(instance.pk)
        logger.info("Push+Telegram queued: booking=%s created", instance.pk)
        return

    if not instance.user_id:
        return

    old_status = getattr(instance, '_original_status', None)
    if old_status == instance.status:
        return

    # Для подтверждения подставляем конкретную дату и время визита
    if instance.status == 'confirmed':
        date_str = instance.date.strftime('%d.%m.%Y')
        time_str = instance.time.strftime('%H:%M')
        title = "Бронирование подтверждено"
        body  = f"Ваш столик забронирован на {date_str} в {time_str}. Ждём вас!"
    else:
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

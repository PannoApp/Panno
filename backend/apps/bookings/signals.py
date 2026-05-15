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


def _safe_delay(task_fn, *args, **kwargs):
    """Вызывает task.delay(), но не роняет запрос при недоступном Redis-брокере."""
    try:
        task_fn.delay(*args, **kwargs)
    except Exception:
        task_name = getattr(task_fn, '__name__', repr(task_fn))
        logger.error(
            "Celery broker unavailable — task %s not queued (args=%s kwargs=%s)",
            task_name, args, kwargs,
        )


@receiver(post_save, sender=TableBooking)
def notify_on_status_change(sender, instance, created, **kwargs):
    from apps.notifications.tasks import send_push_notification

    if created:
        if instance.user_id:
            _safe_delay(
                send_push_notification,
                user_id=instance.user_id,
                title="Заявка принята",
                body="Мы свяжемся с вами в ближайшее время.",
                data={'booking_id': str(instance.pk), 'status': 'pending'},
            )
        from apps.bookings.tasks import send_telegram_notification
        _safe_delay(send_telegram_notification, instance.pk)
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

    _safe_delay(
        send_push_notification,
        user_id=instance.user_id,
        title=title,
        body=body,
        data={'booking_id': str(instance.pk), 'status': instance.status},
    )
    logger.info("Push queued: booking=%s status=%s→%s", instance.pk, old_status, instance.status)

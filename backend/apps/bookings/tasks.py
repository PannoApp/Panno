import logging
from celery import shared_task
from django.core.cache import cache
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)


@shared_task(
    name='apps.bookings.tasks.send_booking_reminders',
    # При сбое БД или Redis повторяем до 3 раз с паузой 60 с.
    # Периодические задачи вызываются Celery Beat, retry безопасен —
    # следующий плановый запуск также проверит то же временное окно.
    # reject_on_worker_lost=True: если воркер убит (SIGKILL) в середине выполнения —
    # задача nack'ается брокером и возвращается в очередь, а не теряется.
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
    reject_on_worker_lost=True,
)
def send_booking_reminders():
    """
    Запускается каждые 15 минут через Celery Beat.
    Отправляет push-напоминание пользователям, у которых подтверждённая бронь
    начинается через 1–2 часа.
    """
    from .models import TableBooking
    from apps.notifications.tasks import send_push_notification

    now = timezone.localtime(timezone.now())
    window_start = now + timedelta(hours=1)
    window_end = now + timedelta(hours=2)

    bookings = TableBooking.objects.filter(
        status='confirmed',
        user__isnull=False,
        date=now.date(),
        time__gte=window_start.time(),
        time__lte=window_end.time(),
    ).select_related('user')

    count = 0
    for booking in bookings:
        # cache.add() атомарен: устанавливает ключ только если его нет.
        # Возвращает False — бронь уже обработана в предыдущем запуске Beat.
        cache_key = f'reminder_sent:{booking.pk}'
        if not cache.add(cache_key, True, timeout=10800):  # TTL = 3 часа
            continue

        send_push_notification.delay(
            user_id=booking.user_id,
            title="Напоминание о визите",
            body=f"Ваш столик забронирован сегодня в {booking.time.strftime('%H:%M')}. Ждём вас!",
            data={'booking_id': str(booking.pk), 'type': 'reminder'},
        )
        count += 1

    logger.info("Booking reminders queued: %d", count)
    return count

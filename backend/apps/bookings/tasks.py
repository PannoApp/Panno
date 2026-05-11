import logging
from celery import shared_task
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)


@shared_task(name='apps.bookings.tasks.send_booking_reminders')
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
        send_push_notification.delay(
            user_id=booking.user_id,
            title="Напоминание о визите",
            body=f"Ваш столик забронирован сегодня в {booking.time.strftime('%H:%M')}. Ждём вас!",
            data={'booking_id': str(booking.pk), 'type': 'reminder'},
        )
        count += 1

    logger.info("Booking reminders queued: %d", count)
    return count

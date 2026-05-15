import html
import logging
import requests
from celery import shared_task
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)

_ZONE_LABELS = {
    'main': 'Главный зал',
    'terrace': 'Терраса',
    'private': 'Приват',
}


@shared_task(
    name='apps.bookings.tasks.send_telegram_notification',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=30,
    acks_late=True,
    reject_on_worker_lost=True,
    # Таймауты: Telegram API обычно отвечает быстро; 60 с — жёсткий предел, 45 с — мягкий (SoftTimeLimitExceeded)
    time_limit=60,
    soft_time_limit=45,
)
def send_telegram_notification(booking_id):
    token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
    chat_id = getattr(settings, 'TELEGRAM_CHAT_ID', '')
    if not token or not chat_id:
        return

    from .models import TableBooking
    try:
        b = TableBooking.objects.select_related('user').get(pk=booking_id)
    except TableBooking.DoesNotExist:
        return

    date_str = b.date.strftime('%d.%m.%Y')
    time_str = b.time.strftime('%H:%M')
    zone_str = _ZONE_LABELS.get(b.zone, b.zone or '—')
    raw_phone = b.phone or (b.user.phone if b.user_id else '')
    phone = html.escape(raw_phone or '—')
    wa_digits = ''.join(c for c in raw_phone if c.isdigit())
    whatsapp_line = f'🔗 <a href="https://wa.me/{wa_digits}">WhatsApp</a>' if wa_digits else ''

    lines = [
        f"🍽 <b>Новое бронирование #{b.pk}</b>",
        "",
        f"👤 {html.escape(b.guest_name)}",
        f"📞 {phone}",
        f"📅 {date_str} в {time_str}",
        f"👥 {b.guests_count} гост.",
        f"🏠 {zone_str}",
    ]
    if b.comment:
        lines.append(f"💬 {html.escape(b.comment)}")
    if whatsapp_line:
        lines.append(whatsapp_line)

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    resp = requests.post(url, json={
        'chat_id': chat_id,
        'text': '\n'.join(lines),
        'parse_mode': 'HTML',
    }, timeout=10)
    if not resp.ok:
        logger.error("Telegram API error: status=%s body=%s", resp.status_code, resp.text)
    resp.raise_for_status()
    logger.info("Telegram notification sent: booking=%s", booking_id)


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
    # Таймауты: периодическая задача — максимум 120 с на итерацию (мягкий: 90 с)
    time_limit=120,
    soft_time_limit=90,
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

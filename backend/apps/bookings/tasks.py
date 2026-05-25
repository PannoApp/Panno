import html
import logging
import requests
from celery import shared_task
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from datetime import timedelta
from django.db.models import Q
from utils.cache import safe_cache_add

logger = logging.getLogger(__name__)

_ZONE_LABELS = {
    'main': 'Главный зал',
    'terrace': 'Терраса',
    'private': 'Приват',
}


def _build_booking_html(b, status_label=None):
    """Возвращает HTML-текст сообщения для Telegram по объекту TableBooking."""
    date_str = b.date.strftime('%d.%m.%Y')
    time_str = b.time.strftime('%H:%M')
    zone_str = _ZONE_LABELS.get(b.zone, b.zone or '—')
    raw_phone = b.phone or (b.user.phone if b.user_id else '')
    phone_escaped = html.escape(raw_phone or '—')
    wa_digits = ''.join(c for c in raw_phone if c.isdigit())
    whatsapp_line = f'🔗 <a href="https://wa.me/{wa_digits}">WhatsApp</a>' if wa_digits else ''

    lines = [
        f"🍽 <b>Бронирование #{b.pk}</b>",
        "",
        f"👤 {html.escape(b.guest_name)}",
        f"📞 {phone_escaped}",
        f"📅 {date_str} в {time_str}",
        f"👥 {b.guests_count} гост.",
        f"🏠 {zone_str}",
    ]
    if b.comment:
        lines.append(f"💬 {html.escape(b.comment)}")
    if whatsapp_line:
        lines.append(whatsapp_line)
    if status_label:
        lines += ["", status_label]
    return '\n'.join(lines)


def _tg_post(method, payload, token, raise_on_error=False):
    """Отправляет запрос к Telegram Bot API. Логирует ошибки, не бросает исключений (если raise_on_error=False)."""
    url = f"https://api.telegram.org/bot{token}/{method}"
    try:
        resp = requests.post(url, json=payload, timeout=10)
        if not resp.ok:
            logger.error("Telegram %s error: status=%s body=%s", method, resp.status_code, resp.text)
            if raise_on_error:
                resp.raise_for_status()
        return resp
    except Exception:
        logger.exception("Telegram %s request failed", method)
        if raise_on_error:
            raise
        return None


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

    text = _build_booking_html(b)
    reply_markup = {
        'inline_keyboard': [[
            {'text': '✅ Подтвердить', 'callback_data': f'confirm:{b.pk}'},
            {'text': '❌ Отменить',    'callback_data': f'cancel:{b.pk}'},
        ]]
    }

    _tg_post('sendMessage', {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': 'HTML',
        'reply_markup': reply_markup,
    }, token, raise_on_error=True)
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

    if window_start.date() == window_end.date():
        time_filter = Q(
            date=window_start.date(),
            time__gte=window_start.time(),
            time__lte=window_end.time()
        )
    else:
        time_filter = (
            Q(date=window_start.date(), time__gte=window_start.time()) |
            Q(date=window_end.date(), time__lte=window_end.time())
        )

    bookings = TableBooking.objects.filter(
        time_filter,
        status='confirmed',
        user__isnull=False,
    ).select_related('user')

    count = 0
    for booking in bookings:
        # safe_cache_add() атомарен: устанавливает ключ только если его нет.
        # Возвращает False — бронь уже обработана в предыдущем запуске Beat.
        cache_key = f'reminder_sent:{booking.pk}'
        if not safe_cache_add(cache_key, True, timeout=10800):  # TTL = 3 часа
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


@shared_task(
    name='apps.bookings.tasks.send_event_reservation_telegram_notification',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=30,
    acks_late=True,
    reject_on_worker_lost=True,
    time_limit=60,
    soft_time_limit=45,
)
def send_event_reservation_telegram_notification(reservation_id):
    """
    Отправляет уведомление в Telegram о новой записи героя на мероприятие.
    """
    token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
    chat_id = getattr(settings, 'TELEGRAM_CHAT_ID', '')
    if not token or not chat_id:
        return

    from apps.events.models import EventReservation
    try:
        r = EventReservation.objects.select_related('user', 'event').get(pk=reservation_id)
    except EventReservation.DoesNotExist:
        return

    name = f"{r.user.first_name} {r.user.last_name}".strip() or r.user.phone
    phone = r.user.phone
    event_title = r.event.title
    event_time = timezone.localtime(r.event.date_time).strftime('%d.%m.%Y %H:%M')
    guests_count = r.guests_count

    max_places = r.event.max_places
    occupied = r.event.occupied_places

    lines = [
        f"🎉 <b>Новая запись на мероприятие #{r.pk}</b>",
        "",
        f"👤 {html.escape(name)}",
        f"📞 {html.escape(phone)}",
        f"📅 {html.escape(event_title)} — {event_time}",
        f"👥 Забронировано: {guests_count} мест(а)",
    ]
    if max_places > 0:
        lines.append(f"🎟 Занято мест: {occupied} из {max_places}")
    else:
        lines.append(f"🎟 Занято мест: {occupied} (без лимита)")

    text = '\n'.join(lines)

    _tg_post('sendMessage', {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': 'HTML',
    }, token, raise_on_error=True)
    logger.info("Telegram notification sent for event reservation: %s", reservation_id)


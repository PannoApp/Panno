import html
import logging
import uuid
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


@shared_task(
    name='apps.bookings.tasks.create_reserve_in_remarked',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=30,
    acks_late=True,
    reject_on_worker_lost=True,
    time_limit=60,
    soft_time_limit=45,
)
def create_reserve_in_remarked(booking_id):
    """
    Создаёт бронь в Remarked (CreateReserve статическим токеном Reserves API,
    см. apps/remarked/reserves_client.py) по уже сохранённой локально
    TableBooking и сохраняет полученный reserve_id обратно.
    Локальная запись — источник истины и остаётся без изменений, если вызов
    в Remarked упадёт после исчерпания ретраев (см. TableBookingListCreateView).
    """
    from .models import TableBooking
    from .services import _free_table_ids_at_slot, pick_table_for_room
    from apps.remarked.exceptions import RemarkedAPIError
    from apps.remarked.reserves_client import ReservesClient

    try:
        booking = TableBooking.objects.select_related('user').get(pk=booking_id)
    except TableBooking.DoesNotExist:
        return

    reserve = {
        'name': booking.guest_name,
        'phone': booking.phone or (booking.user.phone if booking.user_id else ''),
        'date': booking.date.isoformat(),
        'time': booking.time.strftime('%H:%M'),
        'guests_count': booking.guests_count,
        'source': 'mobile_app',
    }
    if booking.comment:
        reserve['comment'] = booking.comment

    if booking.remarked_table_id:
        # Гость явно выбрал конкретный стол в UI (не «Любой стол»), но между
        # показом пикера и выполнением этой (асинхронной) задачи стол мог
        # успеть занять кто-то другой (звонок в ресторан, ручная посадка
        # менеджером в Remarked) — перепроверяем прямо перед CreateReserve.
        # Если стол уже недоступен, просто не передаём table_ids: бронь всё
        # равно создастся, но без привязки к конкретному столу (как «Любой
        # стол» в этом зале), а не тихо конфликтует в Remarked.
        still_free = False
        if booking.remarked_room_id:
            try:
                free_table_ids = _free_table_ids_at_slot(
                    booking.date.isoformat(),
                    booking.time.strftime('%H:%M:%S'),
                    booking.guests_count,
                    booking.remarked_room_id,
                )
                still_free = booking.remarked_table_id in free_table_ids
            except RemarkedAPIError:
                logger.warning(
                    "Table re-check failed, creating reserve without table_ids: booking=%s table=%s",
                    booking_id, booking.remarked_table_id, exc_info=True,
                )
        if still_free:
            reserve['table_ids'] = [booking.remarked_table_id]
    elif booking.remarked_room_id:
        # Гость выбрал зал, но не конкретный стол («Любой стол») — пытаемся
        # честно забронировать стол именно в этом зале, а не полагаться на
        # автоподбор Remarked по всему ресторану. Если между проверкой
        # доступности и созданием брони зал разобрали (или Remarked недоступен
        # для этого доп. запроса) — просто не передаём table_ids, бронь всё
        # равно создастся без привязки к залу.
        try:
            table_id = pick_table_for_room(
                booking.date.isoformat(),
                booking.time.strftime('%H:%M:%S'),
                booking.guests_count,
                booking.remarked_room_id,
            )
        except RemarkedAPIError:
            logger.warning(
                "pick_table_for_room failed, creating reserve without table_ids: booking=%s room=%s",
                booking_id, booking.remarked_room_id, exc_info=True,
            )
            table_id = None
        if table_id:
            reserve['table_ids'] = [table_id]

    client = ReservesClient()
    # Отдельный слой идемпотентности от нашего собственного Idempotency-Key
    # (IdempotencyMixin в views.py) — это ключ, который понимает сам Remarked
    # на уровне метода CreateReserve.
    try:
        response = client.create_reserve(reserve, request_id=str(uuid.uuid4()))
    except RemarkedAPIError as exc:
        if exc.status_code is not None and 200 <= exc.status_code < 300:
            # HTTP 200, но тело — business-level отказ Remarked (например,
            # "Time is restricted to reservation": время визита нарушает
            # правило, настроенное в самом Remarked и не проверяемое через
            # GetSlots). Повтор с теми же датой/временем/гостями провалится
            # так же — ретраить нет смысла, только тратим 3 попытки впустую.
            # Бронь остаётся локально как pending без remarked_reserve_id.
            logger.error(
                "Remarked rejected reserve (non-retryable business rule): booking=%s error=%s",
                booking_id, exc,
            )
            return
        raise

    reserve_id = response.get('reserve_id')
    if reserve_id and booking.remarked_reserve_id != reserve_id:
        booking.remarked_reserve_id = reserve_id
        booking.save(update_fields=['remarked_reserve_id'])
    logger.info("Remarked reserve created: booking=%s reserve_id=%s", booking_id, reserve_id)


# Remarked inner_status (GetReserveByID/GetReservesByPhone) → наш TableBooking.status.
# Архитектурное решение, не согласованное с заказчиком отдельно (см. тикет):
# new/waiting — ещё не подтверждено менеджером → pending;
# confirmed/started — бронь актуальна и гость уже пришёл/подтверждён → confirmed;
# closed — визит завершён → completed;
# canceled — отменена (менеджером или гостем) → canceled.
RESERVE_INNER_STATUS_TO_LOCAL = {
    'new': 'pending',
    'waiting': 'pending',
    'confirmed': 'confirmed',
    'started': 'confirmed',
    'closed': 'completed',
    'canceled': 'canceled',
}


@shared_task(
    name='apps.bookings.tasks.sync_reserve_statuses',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
    reject_on_worker_lost=True,
    time_limit=120,
    soft_time_limit=90,
)
def sync_reserve_statuses():
    """
    Запускается по расписанию Celery Beat (см. CELERY_BEAT_SCHEDULE) —
    обратная синхронизация: менеджер меняет статус брони в Remarked, а не
    в нашем приложении. Для каждой ещё не завершённой локально брони с уже
    известным remarked_reserve_id дёргает GetReserveByID и при расхождении
    статуса обновляет локальную запись. save() триггерит существующий
    post_save-сигнал notify_on_status_change (apps/bookings/signals.py),
    который сам разошлёт пуш пользователю — сигнал не меняется.

    Ошибка Remarked по одной брони не прерывает синхронизацию остальных —
    следующий плановый запуск повторит попытку для неё же.
    """
    from .models import TableBooking
    from apps.remarked.reserves_client import ReservesClient
    from apps.remarked.exceptions import RemarkedAPIError

    bookings = TableBooking.objects.filter(
        status__in=('pending', 'confirmed'),
        remarked_reserve_id__isnull=False,
    )

    client = ReservesClient()
    updated = 0
    for booking in bookings:
        try:
            response = client.get_reserve_by_id(booking.remarked_reserve_id)
        except RemarkedAPIError:
            logger.warning(
                "sync_reserve_statuses: Remarked lookup failed for booking=%s reserve_id=%s",
                booking.pk, booking.remarked_reserve_id, exc_info=True,
            )
            continue

        inner_status = (response.get('reserve') or {}).get('inner_status')
        new_status = RESERVE_INNER_STATUS_TO_LOCAL.get(inner_status)
        if not new_status or new_status == booking.status:
            continue

        booking.status = new_status
        booking.save()
        updated += 1

    logger.info("Reserve statuses synced: %d booking(s) updated", updated)
    return updated


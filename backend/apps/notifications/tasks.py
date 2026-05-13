import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from firebase_admin import messaging

from .models import UserDevice

logger = logging.getLogger(__name__)

_CATEGORY_FLAG = {
    'events': 'notify_events',
    'promotions': 'notify_promotions',
    'closed_events': 'notify_closed_events',
}


@shared_task(
    name='apps.notifications.tasks.send_push_notification',
    # При временном сбое Firebase повторяем до 3 раз с паузой 60 с между попытками.
    # acks_late=True: сообщение удаляется из очереди только после успешного завершения задачи.
    # reject_on_worker_lost=True: если воркер убит (SIGKILL) в процессе выполнения —
    # задача nack'ается брокером и возвращается в очередь, а не теряется.
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
    reject_on_worker_lost=True,
)
def send_push_notification(user_id, title, body, data=None, category=None, campaign_id=None):
    """
    Фоновая задача для отправки пуша конкретному пользователю на все его устройства.

    category — опциональная категория уведомления ('events', 'promotions', 'closed_events').
    Если указана и пользователь отключил эту категорию, push не отправляется.
    Сервисные уведомления (бронь, напоминания) category не передают — всегда доставляются.

    Для маркетинговых пушей (category != None) дополнительно применяются:
    - Лимит частоты: не более PUSH_WEEKLY_LIMIT раз в неделю на пользователя.
    - Временное окно: отправка только в часы PUSH_ALLOWED_HOUR_START–PUSH_ALLOWED_HOUR_END.
      Если текущее время вне окна — задача откладывается через apply_async(eta=...).
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()

    # Проверка настроек для маркетинговых категорий.
    # Сервисные пуши (category=None) — обязательные, настройки не применяются.
    if category and category in _CATEGORY_FLAG:
        flag = _CATEGORY_FLAG[category]
        try:
            user = User.objects.only('notifications_enabled', flag).get(pk=user_id)
            # Глобальный выключатель — отключает все маркетинговые уведомления сразу
            if not user.notifications_enabled:
                logger.info("Push skipped: user=%s notifications_enabled=False", user_id)
                return
            # Категорийный выключатель — пользователь отключил конкретную категорию
            if not getattr(user, flag):
                logger.info("Push skipped: user=%s disabled category=%s", user_id, category)
                return
        except User.DoesNotExist:
            return

    # Ограничения только для маркетинговых пушей (category != None)
    if category:
        # --- Временное окно ---
        now_local = timezone.localtime(timezone.now())
        hour = now_local.hour
        start = settings.PUSH_ALLOWED_HOUR_START
        end   = settings.PUSH_ALLOWED_HOUR_END
        if not (start <= hour < end):
            next_run = now_local.replace(hour=start, minute=0, second=0, microsecond=0)
            if next_run <= now_local:
                next_run += timedelta(days=1)
            send_push_notification.apply_async(
                args=[user_id, title, body, data, category, campaign_id],
                eta=next_run,
            )
            logger.info(
                "Push deferred: user=%s category=%s eta=%s",
                user_id, category, next_run.isoformat(),
            )
            return

        # --- Недельный лимит ---
        week_num = timezone.now().isocalendar()[1]
        week_key = f"push_weekly:{user_id}:{week_num}"
        count = cache.get(week_key, 0)
        if count >= settings.PUSH_WEEKLY_LIMIT:
            logger.info(
                "Push skipped: weekly limit reached user=%s week=%s count=%s",
                user_id, week_num, count,
            )
            return
        cache.set(week_key, count + 1, timeout=7 * 24 * 3600)

    # 1. Собираем все токены пользователя
    devices = UserDevice.objects.filter(user_id=user_id)
    tokens = list(devices.values_list('fcm_token', flat=True))

    if not tokens:
        logger.info(f"У пользователя {user_id} нет зарегистрированных устройств.")
        return

    # 2. Формируем сообщение
    # FCM требует, чтобы все значения data были строками
    str_data = {k: str(v) for k, v in (data or {}).items()}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=str_data,
        tokens=tokens,
    )

    # 3. Отправляем
    # send_multicast использовал устаревший batch-эндпоинт fcm.googleapis.com/batch
    # (Google отключил его — отсюда 404). send_each_for_multicast отправляет
    # каждое сообщение через HTTP v1 API индивидуально.
    response = messaging.send_each_for_multicast(message)

    # 4. Обработка результатов (чистка невалидных токенов)
    if response.failure_count > 0:
        for idx, resp in enumerate(response.responses):
            if not resp.success:
                token_to_remove = tokens[idx]
                UserDevice.objects.filter(fcm_token=token_to_remove).delete()
                logger.warning("Удален невалидный FCM-токен: %s | error: %s", token_to_remove, resp.exception)

    logger.info(f"Отправлено пушей: {response.success_count}, Ошибок: {response.failure_count}")

    if campaign_id:
        from django.db.models import F
        from .models import PushCampaign
        PushCampaign.objects.filter(pk=campaign_id).update(
            delivered_count=F('delivered_count') + response.success_count,
            failed_count=F('failed_count') + response.failure_count,
        )

    return response.success_count


@shared_task(
    name='apps.notifications.tasks.send_bulk_push_notification',
    # Retry при сбое БД или неожиданной ошибке во время постановки подзадач в очередь.
    # reject_on_worker_lost=True: при внезапной гибели воркера задача возвращается в очередь.
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
    reject_on_worker_lost=True,
)
def send_bulk_push_notification(user_ids, title, body, data=None, category=None, campaign_id=None):
    """
    Рассылает push конкретному списку пользователей.
    Вызывает send_push_notification.delay для каждого — Celery сам параллелит.
    Если передан campaign_id — статистика доставки накапливается в PushCampaign.
    """
    queued = 0
    for user_id in user_ids:
        send_push_notification.delay(
            user_id=user_id,
            title=title,
            body=body,
            data=data or {},
            category=category,
            campaign_id=campaign_id,
        )
        queued += 1
    logger.info("Bulk push queued: %d tasks, category=%s, campaign_id=%s", queued, category, campaign_id)
    return queued
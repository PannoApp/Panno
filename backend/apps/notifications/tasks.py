import logging
from celery import shared_task
from firebase_admin import messaging
from .models import UserDevice

logger = logging.getLogger(__name__)

_CATEGORY_FLAG = {
    'events': 'notify_events',
    'promotions': 'notify_promotions',
    'closed_events': 'notify_closed_events',
}


@shared_task(name='apps.notifications.tasks.send_push_notification')
def send_push_notification(user_id, title, body, data=None, category=None):
    """
    Фоновая задача для отправки пуша конкретному пользователю на все его устройства.

    category — опциональная категория уведомления ('events', 'promotions', 'closed_events').
    Если указана и пользователь отключил эту категорию, push не отправляется.
    Сервисные уведомления (бронь, напоминания) category не передают — всегда доставляются.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()

    # Проверка категорийных настроек
    if category and category in _CATEGORY_FLAG:
        flag = _CATEGORY_FLAG[category]
        try:
            user = User.objects.only(flag).get(pk=user_id)
            if not getattr(user, flag):
                logger.info("Push skipped: user=%s disabled category=%s", user_id, category)
                return
        except User.DoesNotExist:
            return

    # 1. Собираем все токены пользователя
    devices = UserDevice.objects.filter(user_id=user_id)
    tokens = list(devices.values_list('fcm_token', flat=True))

    if not tokens:
        logger.info(f"У пользователя {user_id} нет зарегистрированных устройств.")
        return

    # 2. Формируем сообщение
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        tokens=tokens,
    )

    # 3. Отправляем
    response = messaging.send_multicast(message)
    
    # 4. Обработка результатов (чистка невалидных токенов)
    if response.failure_count > 0:
        responses = response.responses
        for idx, resp in enumerate(responses):
            if not resp.success:
                # Если токен невалидный — удаляем его, чтобы не слать в пустоту
                token_to_remove = tokens[idx]
                UserDevice.objects.filter(fcm_token=token_to_remove).delete()
                logger.warning(f"Удален невалидный токен: {token_to_remove}")

    logger.info(f"Отправлено пушей: {response.success_count}, Ошибок: {response.failure_count}")
    return response.success_count


@shared_task(name='apps.notifications.tasks.send_bulk_push_notification')
def send_bulk_push_notification(user_ids, title, body, data=None, category=None):
    """
    Рассылает push конкретному списку пользователей.
    Вызывает send_push_notification.delay для каждого — Celery сам параллелит.
    """
    queued = 0
    for user_id in user_ids:
        send_push_notification.delay(
            user_id=user_id,
            title=title,
            body=body,
            data=data or {},
            category=category,
        )
        queued += 1
    logger.info("Bulk push queued: %d tasks, category=%s", queued, category)
    return queued
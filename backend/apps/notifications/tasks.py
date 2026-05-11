import logging
from celery import shared_task
from firebase_admin import messaging
from .models import UserDevice

logger = logging.getLogger(__name__)

@shared_task(name='apps.notifications.tasks.send_push_notification')
def send_push_notification(user_id, title, body, data=None):
    """
    Фоновая задача для отправки пуша конкретному пользователю на все его устройства.
    """
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
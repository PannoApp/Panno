import logging

import requests
from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)


@shared_task(
    name='apps.users.tasks.send_sms_task',
    bind=True,
    max_retries=3,
    default_retry_delay=30,
    # Таймауты: SMS API обычно быстрый; 60 с — жёсткий предел, 45 с — мягкий
    time_limit=60,
    soft_time_limit=45,
)
def send_sms_task(self, phone: str, otp: str):
    """
    Отправляет SMS через провайдера. OTP уже сохранён в Redis до вызова этой таски.
    При сбое — повторяет до 3 раз с интервалом 30 секунд.
    """
    try:
        response = requests.post(
            settings.SMS_PROVIDER_URL,
            data={
                'login': settings.SMS_LOGIN,
                'psw': settings.SMS_PASSWORD,
                'phones': phone,
                'mes': f'Ваш код для входа в Panno: {otp}',
            },
            timeout=10,
        )
        if response.status_code != 200:
            logger.error(
                "SMS provider error: status=%s body=%s phone=%s",
                response.status_code,
                response.text[:200],
                phone,
            )
            raise self.retry()
    except requests.RequestException as exc:
        logger.error("SMS send failed: phone=%s error=%s", phone, exc)
        raise self.retry(exc=exc)


@shared_task(
    name='apps.users.tasks.sync_guest_from_remarked',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=30,
    acks_late=True,
    reject_on_worker_lost=True,
    time_limit=30,
)
def sync_guest_from_remarked(user_id):
    """
    Фоновый fallback для RemarkedGuestService.sync_on_login (apps/users/services.py):
    та же логика синхронизации, но асинхронно — вызывается, когда синхронный pull
    при логине не удался (таймаут/сеть/Remarked недоступен).
    """
    from .models import User
    from .services import apply_guest_data_to_user
    from apps.remarked.client import RemarkedMobileClient

    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return

    client = RemarkedMobileClient()
    guest = client.get_info_by_phone(user.phone)
    apply_guest_data_to_user(user, guest)


@shared_task(
    name='apps.users.tasks.push_guest_to_remarked',
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=30,
    acks_late=True,
    reject_on_worker_lost=True,
    time_limit=30,
)
def push_guest_to_remarked(user_id, firebase_token=None, device_token=None):
    """
    Отправляет текущее состояние пользователя в Remarked (POST /store/customer/create,
    который работает как upsert по номеру телефона — см. apps/remarked/client.py).
    При первом создании сохраняет `gid` в remarked_guest_id.
    """
    from .models import User
    from apps.remarked.client import RemarkedMobileClient

    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return

    client = RemarkedMobileClient()
    gid = client.create_or_update(user, firebase_token=firebase_token, device_token=device_token)
    if gid and user.remarked_guest_id != gid:
        user.remarked_guest_id = gid
        user.save(update_fields=['remarked_guest_id'])

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

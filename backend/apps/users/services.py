import secrets
import logging
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)


class SMSService:
    @staticmethod
    def generate_otp() -> str:
        return str(secrets.randbelow(9000) + 1000)

    @classmethod
    def send_sms(cls, phone: str) -> bool:
        """
        Генерирует OTP, сохраняет в Redis на 3 минуты, затем ставит задачу Celery
        на асинхронную отправку SMS (gunicorn-worker не блокируется).
        В DEBUG-режиме печатает код в консоль и не вызывает Celery.
        """
        otp = cls.generate_otp()
        cache_key = f"otp_{phone}"
        cache.set(cache_key, otp, timeout=180)

        if settings.DEBUG:
            print(f"\n{'='*30}\nSMS DEV MODE\nPhone: {phone}\nOTP: {otp}\n{'='*30}\n", flush=True)
            return True

        # Боевой режим — HTTP-запрос к SMS-провайдеру выполняется в Celery
        from .tasks import send_sms_task
        send_sms_task.delay(phone, otp)
        return True

    @staticmethod
    def verify_otp(phone: str, otp: str) -> bool:
        """
        Проверяет код из Redis. Если верный - удаляет его.
        """
        cache_key = f"otp_{phone}"
        saved_otp = cache.get(cache_key)
        
        if saved_otp and saved_otp == otp:
            # Если код подошел, удаляем его, чтобы нельзя было использовать дважды
            cache.delete(cache_key)
            return True
            
        return False
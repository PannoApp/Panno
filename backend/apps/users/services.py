import secrets
import logging
import requests
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
        Генерирует OTP, сохраняет в Redis на 3 минуты и отправляет SMS.
        В DEBUG-режиме вместо реальной отправки печатает код в консоль.
        """
        otp = cls.generate_otp()
        cache_key = f"otp_{phone}"
        cache.set(cache_key, otp, timeout=180)

        if settings.DEBUG:
            print(f"\n{'='*30}\nSMS DEV MODE\nPhone: {phone}\nOTP: {otp}\n{'='*30}\n", flush=True)
            return True

        # Боевой режим — HTTP-запрос к SMS-провайдеру
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
            success = response.status_code == 200
            if not success:
                logger.error("SMS provider error: status=%s body=%s phone=%s", response.status_code, response.text[:200], phone)
            return success
        except Exception as e:
            logger.error("SMS send failed: phone=%s error=%s", phone, e)
            return False

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
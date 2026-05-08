import random
import logging
from django.core.cache import cache
from django.conf import settings

# Настраиваем логгер для вывода в консоль
logger = logging.getLogger(__name__)

class SMSService:
    @staticmethod
    def generate_otp() -> str:
        """Генерирует случайный 4-значный код."""
        return str(random.randint(1000, 9999))
    
    @classmethod
    def send_sms(cls, phone:str) -> bool:
        """
        Генерирует OTP, сохраняет в Redis и "отправляет" SMS.
        """
        otp = cls.generate_otp()

        # Сохраняем в кэш (Redis) на 3 минуты (180 секунд)
        cache_key = f"otp_{phone}"
        cache.set(cache_key, otp, timeout=180)

        # ЗАГЛУШКА ДЛЯ РАЗРАБОТКИ
        if settings.DEBUG:
            print(f"\n{'='*30}\nSMS DEV MODE\nPhone: {phone}\nOTP: {otp}\n{'='*30}\n", flush=True)
            return True
        
        # БОЕВОЙ РЕЖИМ (Пример интеграции)
        # В продакшене здесь будет HTTP-запрос к провайдеру:
        # try:
        #     response = requests.post(
        #         "https://smsc.ru/sys/send.php",
        #         data={"login": "твой_логин", "psw": "твой_пароль", "phones": phone, "mes": f"Ваш код: {otp}"}
        #     )
        #     return response.status_code == 200
        # except Exception as e:
        #     logger.error(f"Ошибка отправки SMS: {e}")
        #     return False
        
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
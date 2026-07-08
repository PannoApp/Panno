import secrets
import logging
from django.core.cache import cache
from django.conf import settings
from django.utils.dateparse import parse_date
from utils.cache import safe_cache_set, safe_cache_get, safe_cache_delete
from .models import User

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
        Возвращает False если Redis недоступен — OTP нельзя сохранить, SMS бессмысленен.
        """
        otp = cls.generate_otp()
        cache_key = f"otp_{phone}"
        try:
            cache.set(cache_key, otp, timeout=180)
        except Exception:
            logger.error("Redis unavailable — OTP for %s not stored, SMS aborted", phone)
            return False

        if settings.DEBUG:
            print(f"\n{'='*30}\nSMS DEV MODE\nPhone: {phone}\nOTP: {otp}\n{'='*30}\n", flush=True)
            return True

        # Боевой режим — HTTP-запрос к SMS-провайдеру выполняется в Celery
        from .tasks import send_sms_task
        try:
            send_sms_task.delay(phone, otp)
        except Exception:
            logger.error("Celery broker unavailable — SMS task for %s not queued", phone)
            # OTP уже сохранён в Redis, но SMS не отправится.
            # Возвращаем False чтобы вью уведомил пользователя об ошибке.
            return False

        return True

    @staticmethod
    def verify_otp(phone: str, otp: str) -> bool:
        """
        Проверяет код из Redis. Если верный - удаляет его.
        При недоступном Redis возвращает False (не 500).
        """
        cache_key = f"otp_{phone}"
        saved_otp = safe_cache_get(cache_key)

        if saved_otp and saved_otp == otp:
            # Если код подошел, удаляем его, чтобы нельзя было использовать дважды
            safe_cache_delete(cache_key)
            return True

        return False


# ==========================================
# Remarked — синхронизация гостя
# ==========================================

# Короткий таймаут для синхронного pull при логине — не блокировать вход
# пользователя ожиданием ответа Remarked дольше, чем нужно (обычный
# клиентский таймаут — 10 с, см. apps/remarked/client.py).
REMARKED_LOGIN_SYNC_TIMEOUT = 3


def apply_guest_data_to_user(user, guest):
    """
    Перезаписывает first_name/last_name/email/birthday/gender данными гостя
    из Remarked и сохраняет remarked_guest_id. Remarked — источник истины при
    конфликте: непустое поле в ответе побеждает локальное значение.

    Пустые/отсутствующие в ответе Remarked поля локальные данные НЕ затирают —
    иначе первый же логин гостя с неполной карточкой в CRM обнулил бы то, что
    человек уже успел ввести в приложении.

    Возвращает True, если что-то изменилось и было сохранено.
    """
    if not guest:
        return False

    changed_fields = []
    if guest.get('name'):
        user.first_name = guest['name']
        changed_fields.append('first_name')
    if guest.get('surname'):
        user.last_name = guest['surname']
        changed_fields.append('last_name')
    if guest.get('email'):
        user.email = guest['email']
        changed_fields.append('email')
    if guest.get('birthday'):
        parsed = parse_date(guest['birthday'])
        if parsed:
            user.birthday = parsed
            changed_fields.append('birthday')
    if guest.get('gender') in (User.GENDER_MALE, User.GENDER_FEMALE):
        user.gender = guest['gender']
        changed_fields.append('gender')
    if guest.get('id'):
        user.remarked_guest_id = str(guest['id'])
        changed_fields.append('remarked_guest_id')

    if not changed_fields:
        return False

    user.save(update_fields=changed_fields)
    return True


class RemarkedGuestService:
    """
    Синхронизация гостя с Remarked при логине (см. VerifySMSView).

    Синхронный pull с коротким таймаутом — пользователь должен увидеть данные,
    подтянутые из CRM, сразу на экране после входа, а не через несколько секунд
    после фонового Celery-таска. Если синхронный вызов не удался (таймаут, сеть,
    Remarked недоступен) — логин не должен падать: вместо этого синхронизация
    ставится в очередь Celery как fallback (тот же паттерн, что и
    SMSService.send_sms при недоступном Celery-брокере).
    """

    @staticmethod
    def sync_on_login(user):
        from apps.remarked.client import RemarkedMobileClient
        from apps.remarked.exceptions import RemarkedAPIError

        try:
            client = RemarkedMobileClient(timeout=REMARKED_LOGIN_SYNC_TIMEOUT)
            guest = client.get_info_by_phone(user.phone)
        except RemarkedAPIError as exc:
            logger.warning("Remarked sync-on-login failed for user=%s: %s", user.pk, exc)
            RemarkedGuestService._queue_fallback(user.pk)
            return
        except Exception:
            logger.exception("Remarked sync-on-login unexpected error: user=%s", user.pk)
            RemarkedGuestService._queue_fallback(user.pk)
            return

        if guest:
            apply_guest_data_to_user(user, guest)

    @staticmethod
    def _queue_fallback(user_id):
        from .tasks import sync_guest_from_remarked
        try:
            sync_guest_from_remarked.delay(user_id)
        except Exception:
            logger.error("Celery broker unavailable — sync_guest_from_remarked not queued: user=%s", user_id)


def maybe_push_guest_to_remarked(user, firebase_token=None, device_token=None):
    """
    Ставит push_guest_to_remarked в очередь, если это имеет смысл:
    (а) у гостя уже есть remarked_guest_id — обычный upsert текущего состояния, либо
    (б) гостя в Remarked ещё нет, но онбординг уже дал достаточно данных для
        первого создания (имя + явно выбранный пол — не "not_specified").

    Пока условие (б) не выполнено, лишние вызовы customer/create не шлём —
    Remarked требует непустые name/gender, а до конца анкеты их может не быть.
    Не роняет вызывающий запрос при недоступном Celery-брокере.
    """
    has_min_profile = bool(user.first_name) and user.gender != User.GENDER_NOT_SPECIFIED
    if not (user.remarked_guest_id or has_min_profile):
        return

    from .tasks import push_guest_to_remarked
    try:
        push_guest_to_remarked.delay(user.id, firebase_token=firebase_token, device_token=device_token)
    except Exception:
        logger.error("Celery broker unavailable — push_guest_to_remarked not queued: user=%s", user.id)
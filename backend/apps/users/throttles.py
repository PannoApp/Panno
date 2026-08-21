import logging
from rest_framework.throttling import SimpleRateThrottle, ScopedRateThrottle

logger = logging.getLogger(__name__)


class _RedisResistantThrottleMixin:
    """
    При недоступном Redis throttle пропускает запрос (fail open).
    Альтернатива — блокировать всех, что хуже.
    """

    def allow_request(self, request, view):
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning("Redis unavailable — throttle skipped for %s", self.__class__.__name__)
            return True


class SafeScopedRateThrottle(_RedisResistantThrottleMixin, ScopedRateThrottle):
    """ScopedRateThrottle с защитой от падения Redis."""


class PhoneSMSThrottle(_RedisResistantThrottleMixin, SimpleRateThrottle):
    """
    Второй уровень троттлинга для запросов SMS — по номеру телефона.

    Ограничение: не более 5 запросов на один номер за 10 минут.
    Работает независимо от IP-адреса клиента, защищая от распределённых
    атак (разные IP → один номер) и спама на чужой номер.

    Ключ в Redis: throttle_sms_request_phone_{номер_телефона}
    При недоступном Redis — пропускает запрос (fail open).
    """

    scope = 'sms_request_phone'

    # Лимит: 5 запросов за 10 минут на один номер телефона
    _NUM_REQUESTS = 5
    _DURATION = 10 * 60  # 600 секунд

    def get_rate(self):
        # Возвращаем строку-заглушку; реальные значения задаются в parse_rate
        return f'{self._NUM_REQUESTS}/min'

    def parse_rate(self, rate):
        # Игнорируем строку из settings и используем жёстко заданные значения
        if rate is None:
            return (None, None)
        return (self._NUM_REQUESTS, self._DURATION)

    def get_cache_key(self, request, view):
        """
        Возвращает ключ Redis, основанный на номере телефона из тела запроса.
        Если телефон не передан — возвращаем None, чтобы не блокировать запрос
        (валидация номера произойдёт позже, на уровне сериализатора).
        """
        phone = request.data.get('phone')
        if not phone:
            return None
        return self.cache_format % {
            'scope': self.scope,
            'ident': phone,
        }


class LoyaltyLoginPhoneThrottle(_RedisResistantThrottleMixin, SimpleRateThrottle):
    """
    Троттлинг по номеру телефона для входа по номеру участника лояльности
    (LoyaltyLoginView). Номер участника фактически выполняет роль пароля
    (ТЗ по входу, открытый вопрос №3) — без лимита по конкретному телефону
    его можно подбирать перебором в обход общего лимита по IP.

    Ограничение: не более 5 попыток на один номер за 10 минут.
    При недоступном Redis — пропускает запрос (fail open), как и другие
    троттлы в этом модуле.
    """

    scope = 'loyalty_login_phone'

    _NUM_REQUESTS = 5
    _DURATION = 10 * 60  # 600 секунд

    def get_rate(self):
        return f'{self._NUM_REQUESTS}/min'

    def parse_rate(self, rate):
        if rate is None:
            return (None, None)
        return (self._NUM_REQUESTS, self._DURATION)

    def get_cache_key(self, request, view):
        phone = request.data.get('phone')
        if not phone:
            return None
        return self.cache_format % {
            'scope': self.scope,
            'ident': phone,
        }


class LoyaltyRegisterPhoneThrottle(_RedisResistantThrottleMixin, SimpleRateThrottle):
    """
    Троттлинг по номеру телефона для регистрации нового гостя лояльности
    (LoyaltyRegisterView). Регистрация пишет реальные данные в Remarked CRM —
    без лимита по телефону возможен спам фиктивными гостями.

    Ограничение: не более 3 попыток на один номер за 10 минут (жёстче входа —
    в норме на номер приходится ровно одна успешная регистрация).
    """

    scope = 'loyalty_register_phone'

    _NUM_REQUESTS = 3
    _DURATION = 10 * 60  # 600 секунд

    def get_rate(self):
        return f'{self._NUM_REQUESTS}/min'

    def parse_rate(self, rate):
        if rate is None:
            return (None, None)
        return (self._NUM_REQUESTS, self._DURATION)

    def get_cache_key(self, request, view):
        phone = request.data.get('phone')
        if not phone:
            return None
        return self.cache_format % {
            'scope': self.scope,
            'ident': phone,
        }

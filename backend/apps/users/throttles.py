from rest_framework.throttling import SimpleRateThrottle


class PhoneSMSThrottle(SimpleRateThrottle):
    """
    Второй уровень троттлинга для запросов SMS — по номеру телефона.

    Ограничение: не более 5 запросов на один номер за 10 минут.
    Работает независимо от IP-адреса клиента, защищая от распределённых
    атак (разные IP → один номер) и спама на чужой номер.

    Ключ в Redis: throttle_sms_request_phone_{номер_телефона}
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

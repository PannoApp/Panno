from .base import *
from datetime import timedelta

DEBUG = True

# В dev разрешаем любой Host: телефон/эмулятор стучится на LAN-IP машины,
# который меняется по DHCP. Перечислять IP вручную в .env бессмысленно —
# список постоянно устаревает. Это безопасно, т.к. dev-настройки никогда не
# идут в прод (wsgi.py/asgi.py жёстко используют config.settings.prod, где
# ALLOWED_HOSTS берётся из окружения и остаётся строгим).
ALLOWED_HOSTS = ['*']

# Увеличиваем TTL access-токена для удобства разработки (в base.py стоит 30 минут для прода)
SIMPLE_JWT = {
    **SIMPLE_JWT,
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
}

# Включаем вывод email-сообщений в консоль (чтобы не настраивать реальный SMTP локально)
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Разрешаем все источники для локальной разработки (Flutter-эмулятор, браузер, Postman)
CORS_ALLOW_ALL_ORIGINS = True
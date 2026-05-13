from .base import *
from datetime import timedelta


# Переопределяем и добавляем настройки, специфичные только для локальной разработки

# Увеличиваем TTL access-токена для удобства разработки (в base.py стоит 30 минут для прода)
SIMPLE_JWT = {
    **SIMPLE_JWT,
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
}

# Включаем вывод email-сообщений в консоль (чтобы не настраивать реальный SMTP локально)
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Если будешь локально тестировать API с фронтендом или мобильным приложением (CORS)
# Требует установки пакета django-cors-headers (добавим позже при необходимости)
# CORS_ALLOW_ALL_ORIGINS = True

# Здесь позже можно подключить инструменты для дебага, например:
# INSTALLED_APPS += ['debug_toolbar']
# MIDDLEWARE += ['debug_toolbar.middleware.DebugToolbarMiddleware']
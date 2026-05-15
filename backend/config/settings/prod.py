from .base import *
from datetime import timedelta
from django.core.exceptions import ImproperlyConfigured

DEBUG = False

SIMPLE_JWT = {
    **SIMPLE_JWT,
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),
}

# Парсим строку из .env (например, "127.0.0.1,example.com") в список
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=[])

# ==========================================
# Безопасность
# ==========================================
# Рекомендуется раскомментировать эти строки, когда прикрутишь SSL (HTTPS) на сервере
# SECURE_SSL_REDIRECT = True
# SESSION_COOKIE_SECURE = True
# CSRF_COOKIE_SECURE = True

# Заголовки безопасности — не требуют SSL, безопасны на HTTP тоже
SECURE_CONTENT_TYPE_NOSNIFF = True     # Запрещает браузеру угадывать MIME-тип
SECURE_BROWSER_XSS_FILTER = True       # Включает XSS-фильтр в старых браузерах
X_FRAME_OPTIONS = 'DENY'               # Запрещает вставку страниц в <iframe>

# ==========================================
# Проверка обязательных переменных окружения в production
# ==========================================
# В debug-режиме все переменные могут быть пустыми (удобно для локальной разработки).
# В production отсутствие этих значений — признак ошибочного деплоя.
_REQUIRED_VARS = {
    'SMS_PROVIDER_URL': SMS_PROVIDER_URL,
    'SMS_LOGIN': SMS_LOGIN,
    'SMS_PASSWORD': SMS_PASSWORD,
    'FIREBASE_CREDENTIALS_PATH': FIREBASE_CREDENTIALS_PATH,
    'TELEGRAM_BOT_TOKEN': TELEGRAM_BOT_TOKEN,
    'TELEGRAM_CHAT_ID': TELEGRAM_CHAT_ID,
}
_missing = [name for name, val in _REQUIRED_VARS.items() if not val]
if _missing:
    raise ImproperlyConfigured(
        f"В production-режиме обязательны следующие переменные окружения: {', '.join(_missing)}"
    )

# ==========================================
# Статика и Медиа
# ==========================================
# Конфигурация django-storages задаётся в base.py через USE_S3=True.
# В production все медиа-файлы должны лежать в S3, а не в контейнере.
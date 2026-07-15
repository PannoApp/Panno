from .base import *
from django.core.exceptions import ImproperlyConfigured

DEBUG = False

# Парсим строку из .env (например, "127.0.0.1,example.com") в список
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=[])

# Разрешаем только конкретные источники (Flutter-приложение, веб-клиент)
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[])

# ==========================================
# Безопасность
# ==========================================
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'

# Включить после настройки HTTPS на сервере:
# SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True

# ==========================================
# Проверка обязательных переменных окружения в production
# ==========================================
_REQUIRED_VARS = {
    'SMS_PROVIDER_URL': SMS_PROVIDER_URL,
    'SMS_LOGIN': SMS_LOGIN,
    'SMS_PASSWORD': SMS_PASSWORD,
    'FIREBASE_CREDENTIALS_PATH': FIREBASE_CREDENTIALS_PATH,
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
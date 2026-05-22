from .base import *

DEBUG = True

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}

PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# Используем in-memory брокер, чтобы .delay() не требовал запущенного Redis
CELERY_BROKER_URL = 'memory://'
# Задачи выполняются синхронно — результат доступен сразу в тестах
CELERY_TASK_ALWAYS_EAGER = True

# Отключаем глобальный throttling в тестах: тесты не должны получать 429
# из-за накопившихся запросов в LocMemCache между вызовами.
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    'DEFAULT_THROTTLE_CLASSES': [],
    'DEFAULT_THROTTLE_RATES': {},
}

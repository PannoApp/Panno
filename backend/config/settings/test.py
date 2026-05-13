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

DEFAULT_FILE_STORAGE = 'django.core.files.storage.InMemoryStorage'

# Используем in-memory брокер, чтобы .delay() не требовал запущенного Redis
CELERY_BROKER_URL = 'memory://'
CELERY_TASK_ALWAYS_EAGER = False

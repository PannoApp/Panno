import os
import sys
from pathlib import Path
import environ
from datetime import timedelta

# Путь к корню проекта. Так как этот файл лежит в config/settings/,
# нам нужно подняться на 3 уровня вверх (settings -> config -> корень)
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Добавляем путь к папке apps в sys.path, чтобы импортировать приложения напрямую
sys.path.insert(0, os.path.join(BASE_DIR, 'apps'))
# Инициализация django-environ для чтения переменных окружения
env = environ.Env(
    # Задаем дефолтное значение для DEBUG
    DEBUG=(bool, False)
)

# Читаем файл .env, если он существует (для локальной разработки)
# В Docker переменные могут прокидываться напрямую, без файла
environ.Env.read_env(os.path.join(BASE_DIR, '.env'))

# Базовые ключи безопасности
SECRET_KEY = env('SECRET_KEY')
DEBUG = env('DEBUG')

# Читаем список хостов из переменной окружения
# Если переменная пустая, оставляем пустой список
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=[])

# Стандартные приложения Django
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_filters',
    
    # Мои приложения
    'users.apps.UsersConfig',
    'menu.apps.MenuConfig',
    'bookings.apps.BookingsConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [], # Позже можно добавить os.path.join(BASE_DIR, 'templates')
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# Точки входа серверов (файлы создадим в следующих шагах)
WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'

# База данных PostgreSQL (данные берем из .env)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': env('POSTGRES_DB'),
        'USER': env('POSTGRES_USER'),
        'PASSWORD': env('POSTGRES_PASSWORD'),
        'HOST': env('POSTGRES_HOST'),
        'PORT': env('POSTGRES_PORT'),
    }
}

# Валидаторы паролей по умолчанию
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Локализация
LANGUAGE_CODE = 'ru-ru'
TIME_ZONE = 'Asia/Almaty'
USE_I18N = True
USE_TZ = True

# Статика (локально)
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Кэширование через Redis (для сессий и быстрых данных)
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": env('REDIS_URL'),
    }
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ==========================================
# Хранилище файлов (Static & Media)
# ==========================================

# Определяем, используем ли мы S3
USE_S3 = env.bool('USE_S3', default=False)

if USE_S3:
    # Настройки для django-storages (Boto3)
    AWS_ACCESS_KEY_ID = env('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = env('AWS_SECRET_ACCESS_KEY')
    AWS_STORAGE_BUCKET_NAME = env('AWS_STORAGE_BUCKET_NAME')
    AWS_S3_REGION_NAME = env('AWS_S3_REGION_NAME', default=None)
    AWS_S3_ENDPOINT_URL = env('AWS_S3_ENDPOINT_URL', default=None)
    
    # S3 Custom Domain (если используем CDN, иначе формируется автоматически)
    AWS_S3_CUSTOM_DOMAIN = env('AWS_S3_CUSTOM_DOMAIN', default=None)
    
    # Настройки поведения
    AWS_S3_OBJECT_PARAMETERS = {
        'CacheControl': 'max-age=86400', # Кэшировать файлы на сутки
    }
    # Важно для совместимости с разными провайдерами (MinIO, Selectel)
    AWS_S3_FILE_OVERWRITE = False 
    AWS_DEFAULT_ACL = None # Современный стандарт — управление доступом через Bucket Policies

    # Конфигурация хранилищ для Django 5.0
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "location": "media", # Все медиа-файлы будут в папке /media/ внутри бакета
            },
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }
    
    # URL для медиа-файлов
    if AWS_S3_CUSTOM_DOMAIN:
        MEDIA_URL = f'https://{AWS_S3_CUSTOM_DOMAIN}/media/'
    else:
        # Если эндпоинт указан (MinIO), используем его, иначе стандартный S3 URL
        base_url = AWS_S3_ENDPOINT_URL.replace('http://minio', 'http://localhost') if AWS_S3_ENDPOINT_URL else f'https://{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com'
        MEDIA_URL = f'{base_url}/media/'

else:
    # Локальное хранилище (если S3 не настроен)
    STORAGES = {
        "default": {
            "BACKEND": "django.core.files.storage.FileSystemStorage",
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }
    MEDIA_URL = '/media/'
    MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Указываем Django использовать нашу кастомную модель
AUTH_USER_MODEL = 'users.User'

# Настройки Django REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.AllowAny', # По умолчанию открыто, закрывать будем конкретные эндпоинты
    ),
    # ДОБАВЛЯЕМ ТРОТТЛИНГ
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'sms_request': '3/min',  # 3 запроса в минуту с одного IP
        'sms_verify': '5/min',   # 5 проверок в минуту с одного IP
        # 'sms_request_day': '20/day', # Можно комбинировать, если нужно
    },
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend'
    ),
}

# Настройки SimpleJWT
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1), # Для разработки ставим 1 день. В проде изменим на 15-30 минут
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': False,
    'BLACKLIST_AFTER_ROTATION': False,
    'UPDATE_LAST_LOGIN': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}
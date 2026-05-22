import os
from pathlib import Path
import environ
from datetime import timedelta

# Путь к корню проекта. Так как этот файл лежит в config/settings/,
# нам нужно подняться на 3 уровня вверх (settings -> config -> корень)
BASE_DIR = Path(__file__).resolve().parent.parent.parent

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

    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'django_filters',
    'drf_spectacular',
    'corsheaders',

    # Blacklist для JWT: хранит отозванные refresh-токены в БД
    'rest_framework_simplejwt.token_blacklist',

    # Мои приложения
    'apps.users.apps.UsersConfig',
    'apps.menu.apps.MenuConfig',
    'apps.bookings.apps.BookingsConfig',
    'apps.events.apps.EventsConfig',
    'apps.core.apps.CoreConfig',
    'apps.notifications.apps.NotificationsConfig',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'utils.logging_middleware.RequestLoggingMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

from corsheaders.defaults import default_headers
CORS_ALLOW_HEADERS = list(default_headers) + [
    'idempotency-key',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
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
        # Указываем имя контейнера pgbouncer из твоего docker-compose.yml
        'HOST': env('POSTGRES_HOST'),
        # Указываем порт, который слушает PgBouncer
        'PORT': env('POSTGRES_PORT'),
        # КРИТИЧНО для режима POOL_MODE=transaction:
        # Отключаем серверные курсоры, так как PgBouncer в этом режиме 
        # не гарантирует сохранение сессии между запросами.
        'DISABLE_SERVER_SIDE_CURSORS': True,
    }
}

# AUTH_PASSWORD_VALIDATORS намеренно не задан: все пользователи аутентифицируются
# через SMS OTP и имеют unusable_password — валидаторы паролей к ним никогда
# не применяются и создавали бы ложное впечатление о наличии пароля.

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
    elif AWS_S3_ENDPOINT_URL:
        MEDIA_URL = f'{AWS_S3_ENDPOINT_URL}/{AWS_STORAGE_BUCKET_NAME}/media/'
    else:
        MEDIA_URL = f'https://{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com/media/'

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

# ==========================================
# SMS-провайдер
# ==========================================
SMS_PROVIDER_URL = env('SMS_PROVIDER_URL', default='')
SMS_LOGIN = env('SMS_LOGIN', default='')
SMS_PASSWORD = env('SMS_PASSWORD', default='')

# ==========================================
# Firebase (FCM)
# ==========================================
FIREBASE_CREDENTIALS_PATH = env('FIREBASE_CREDENTIALS_PATH', default='')

# ==========================================
# Telegram Bot
# ==========================================
TELEGRAM_BOT_TOKEN = env('TELEGRAM_BOT_TOKEN', default='')
TELEGRAM_CHAT_ID = env('TELEGRAM_CHAT_ID', default='')
# Секрет для верификации входящих webhook-запросов от Telegram (X-Telegram-Bot-Api-Secret-Token)
TELEGRAM_WEBHOOK_SECRET = env('TELEGRAM_WEBHOOK_SECRET', default='')


# Настройки Django REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.AllowAny', # По умолчанию открыто, закрывать будем конкретные эндпоинты
    ),
    # Глобальные классы троттлинга:
    # AnonRateThrottle/UserRateThrottle — защита всех эндпоинтов от массового перебора.
    # ScopedRateThrottle — точечный контроль SMS-эндпоинтов (задаётся через throttle_scope).
    # Представления, которые явно задают throttle_classes, переопределяют этот список.
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        # Глобальные лимиты: анонимные запросы (по IP) и аутентифицированные (по user_id)
        'anon': '60/min',
        'user': '300/min',
        # Точечные лимиты для SMS: жёстче, т.к. каждый запрос стоит денег
        'sms_request': '3/min',  # 3 запроса в минуту с одного IP
        'sms_verify': '5/min',   # 5 проверок в минуту с одного IP
    },
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
    ],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'EXCEPTION_HANDLER': 'utils.exception_handler.custom_exception_handler',
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'Panno Restaurant API',
    'DESCRIPTION': (
        'REST API для мобильного приложения ресторана Panno.\n\n'
        '## Авторизация\n'
        'Большинство эндпоинтов требуют JWT Bearer токен. Получить его можно через:\n'
        '1. `POST /api/users/auth/request-sms/` — запросить SMS с кодом\n'
        '2. `POST /api/users/auth/verify-sms/` — подтвердить код и получить токены\n\n'
        'Далее передавайте заголовок: `Authorization: Bearer <access_token>`'
    ),
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'CONTACT': {'name': 'Panno Dev Team'},
    'SERVERS': [
        {'url': 'http://localhost:8000', 'description': 'Локальная разработка'},
    ],
    'COMPONENT_SPLIT_REQUEST': True,
    'SORT_OPERATIONS': False,
    'ENUM_GENERATE_CHOICE_DESCRIPTION': False,
    'SWAGGER_UI_SETTINGS': {
        'persistAuthorization': True,
        'displayRequestDuration': True,
        'filter': True,
    },
    'TAGS': [
        {'name': 'Auth', 'description': 'Авторизация через SMS OTP и управление профилем'},
        {'name': 'Menu', 'description': 'Категории и блюда меню ресторана'},
        {'name': 'Events', 'description': 'Мероприятия, новости и запись на события'},
        {'name': 'Bookings', 'description': 'Бронирование столов'},
        {'name': 'Core', 'description': 'Общая информация о ресторане'},
        {'name': 'Notifications', 'description': 'Push-уведомления (FCM устройства)'},
    ],
}

# Настройки SimpleJWT
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),  # Продовое значение: короткий TTL снижает риск утечки токена
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    # При каждом refresh выдаётся новый refresh-токен, старый попадает в blacklist
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}


# ==========================================
# Настройки Celery и Redis
# ==========================================

# URL брокера сообщений (Redis). 
# В Docker-compose сервис обычно называется 'redis'. 
# Если запускаешь локально без Docker, используй 'redis://127.0.0.1:6379/0'
CELERY_BROKER_URL = env('CELERY_BROKER_URL', default='redis://redis:6379/0')

# Результаты задач не используются нигде в коде (.AsyncResult() отсутствует),
# поэтому отключаем сохранение результатов, чтобы не занимать место в Redis.
CELERY_TASK_IGNORE_RESULT = True

# Форматы данных
CELERY_ACCEPT_CONTENT = ['application/json']
CELERY_TASK_SERIALIZER = 'json'

# Часовой пояс для периодических задач (синхронизируем с Django)
CELERY_TIMEZONE = TIME_ZONE

# Переподключение к брокеру при старте и в рантайме.
# Без этого worker падает навсегда при временной недоступности Redis.
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True
CELERY_BROKER_CONNECTION_RETRY = True
CELERY_BROKER_CONNECTION_MAX_RETRIES = 10

# Периодические задачи (Celery Beat)
CELERY_BEAT_SCHEDULE = {
    'send-booking-reminders': {
        'task': 'apps.bookings.tasks.send_booking_reminders',
        'schedule': 60 * 15,  # каждые 15 минут
    },
}

CELERY_TASK_ROUTES = {
    'apps.menu.tasks.process_dish_video': {'queue': 'video'},
}

# ==========================================
# Push-уведомления: ограничения
# ==========================================

# Максимум маркетинговых пушей на пользователя в неделю (category != None)
PUSH_WEEKLY_LIMIT = env.int('PUSH_WEEKLY_LIMIT', default=3)

# Разрешённое окно отправки маркетинговых пушей (часы, локальное время сервера)
PUSH_ALLOWED_HOUR_START = env.int('PUSH_ALLOWED_HOUR_START', default=9)
PUSH_ALLOWED_HOUR_END   = env.int('PUSH_ALLOWED_HOUR_END', default=21)

# ==========================================
# Логирование
# ==========================================

LOGS_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOGS_DIR, exist_ok=True)

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'json': {
            '()': 'utils.logging_middleware.JsonFormatter',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': os.path.join(LOGS_DIR, 'app.log'),
            'maxBytes': 10 * 1024 * 1024,  # 10 МБ
            'backupCount': 5,
            'formatter': 'json',
            'encoding': 'utf-8',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'json',
        },
    },
    'loggers': {
        'django.request': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
        # Логгер для нашего кастомного middleware (если использовать logger = logging.getLogger(__name__))
        'utils.logging_middleware': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# ==========================================
# Jazzmin — тема админ-панели
# ==========================================

JAZZMIN_SETTINGS = {
    "site_title": "Пилигрим",
    "site_header": "Пилигрим — Панель управления",
    "site_brand": "Пилигрим",
    "welcome_sign": "Добро пожаловать в панель управления",
    "copyright": "Piligrim Restaurant",

    # Глобальный поиск по моделям
    "search_model": ["users.User", "menu.Dish", "bookings.TableBooking"],

    # Иконки FontAwesome 5 Free
    "icons": {
        "auth":                          "fas fa-users-cog",
        "users.user":                    "fas fa-user",
        "menu.category":                 "fas fa-th-large",
        "menu.dish":                     "fas fa-utensils",
        "menu.tag":                      "fas fa-tag",
        "menu.allergen":                 "fas fa-exclamation-triangle",
        "events.event":                  "fas fa-calendar-alt",
        "events.news":                   "fas fa-newspaper",
        "events.eventreservation":       "fas fa-ticket-alt",
        "bookings.tablebooking":         "fas fa-chair",
        "notifications.userdevice":      "fas fa-mobile-alt",
        "notifications.pushcampaign":    "fas fa-bell",
        "core.restaurantinfo":           "fas fa-store",
        "core.interiorphoto":            "fas fa-images",
        "core.appversion":               "fas fa-code-branch",
    },

    # Порядок разделов в сайдбаре
    "order_with_respect_to": [
        "bookings",
        "events",
        "menu",
        "core",
        "users",
        "notifications",
    ],

    # Скрыть стандартный раздел auth — используем кастомные роли через users.User
    "hide_apps": ["auth"],

    "show_ui_builder": False,
    "navigation_expanded": True,
    "show_sidebar": True,
    "autosize_content": True,

    "topmenu_links": [
        {"name": "Сайт",     "url": "/",          "new_window": True},
        {"name": "API Docs", "url": "/api/docs/", "new_window": True},
        {"name": "Выйти",    "url": "/admin/logout/", "new_window": False},
    ],
    "usermenu_links": [
        {"name": "API Docs", "url": "/api/docs/", "new_window": True},
        {"name": "Выйти",    "url": "/admin/logout/", "new_window": False},
    ],
}

JAZZMIN_UI_TWEAKS = {
    "navbar_small_text":      False,
    "footer_small_text":      False,
    "body_small_text":        False,
    "brand_small_text":       False,
    "brand_colour":           "navbar-dark",
    "accent":                 "accent-danger",
    "navbar":                 "navbar-dark",
    "no_navbar_border":       True,
    "navbar_fixed":           True,
    "layout_boxed":           False,
    "footer_fixed":           False,
    "sidebar_fixed":          True,
    "sidebar":                "sidebar-dark-maroon",
    "sidebar_nav_small_text":     False,
    "sidebar_disable_expand":     False,
    "sidebar_nav_child_indent":   True,
    "sidebar_nav_compact_style":  False,
    "sidebar_nav_legacy_style":   False,
    "sidebar_nav_flat_style":     False,
    "theme": "flatly",
    "button_classes": {
        "primary":   "btn-primary",
        "secondary": "btn-secondary",
        "info":      "btn-info",
        "warning":   "btn-warning",
        "danger":    "btn-danger",
        "success":   "btn-success",
    },
}

LOGIN_REDIRECT_URL = '/admin/'


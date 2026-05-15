import os
from django.core.asgi import get_asgi_application

# Аналогично wsgi.py, по умолчанию для асинхронного сервера используем продакшен-настройки.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.prod')

application = get_asgi_application()
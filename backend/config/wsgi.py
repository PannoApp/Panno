import os 
from django.core.wsgi import get_wsgi_application

# По умолчанию для WSGI сервера ставим продакшен-настройки.
# Если мы запускаем локальный сервер через manage.py runserver, 
# он будет использовать dev.py (как мы указали в manage.py).
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.prod')

application = get_wsgi_application()
import os
from celery import Celery

# Устанавливаем модуль настроек Django по умолчанию для программы 'celery'
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')

app = Celery('piligrim')

# Загружаем натсройки из файла base.py
app.config_from_object('django.conf:settings', namespace='CELERY')

# Автоматически находим и загружаем задачи (tasks.py) из всех установленных приложений Django
app.autodiscover_tasks()
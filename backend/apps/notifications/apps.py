import logging
import os

import firebase_admin
from django.apps import AppConfig
from django.conf import settings
from firebase_admin import credentials

logger = logging.getLogger(__name__)


class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.notifications'
    verbose_name = 'Уведомления'

    def ready(self):
        # Проверяем, не инициализировано ли приложение уже (важно для дебаг-сервера с auto-reload)
        if firebase_admin._apps:
            return

        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', '')

        if not cred_path or not os.path.exists(cred_path):
            # Логируем WARNING вместо print — сообщение попадёт в app.log и не потеряется
            logger.warning(
                "Firebase credentials не найдены по пути '%s'. "
                "Push-уведомления работать не будут.",
                cred_path or '<не задан>',
            )
            return

        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase успешно инициализирован (%s).", cred_path)
from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.core'
    verbose_name = "Основные настройки"

    def ready(self):
        from . import signals  # noqa: F401 — подключаем сигналы инвалидации кэша

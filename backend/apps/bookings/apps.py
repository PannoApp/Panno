from django.apps import AppConfig
from django.db.models.signals import post_migrate


def create_manager_group(sender, **kwargs):
    """
    Создает группу 'Менеджер зала' и выдает права только на просмотр и изменение броней.
    Сигнал срабатывает автоматически после применения миграций.
    """
    # Импортируем внутри функции, чтобы избежать проблем с цикличными импортами при старте Django
    from django.contrib.auth.models import Group, Permission
    from django.contrib.contenttypes.models import ContentType
    from .models import TableBooking

    # Создаем группу 'Менеджер зала', если она еще не существует
    manager_group, created = Group.objects.get_or_create(name='Менеджер зала')

    # Получаем тип контента для нашей модели бронирования
    content_type = ContentType.objects.get_for_model(TableBooking)

    # Выбираем права: 'view' (просмотр) и 'change' (изменение статуса)
    # Мы не даем 'add' (добавление) и 'delete' (удаление), чтобы менеджер не мог удалять историю
    permissions = Permission.objects.filter(
        content_type=content_type,
        codename__in=['view_tablebooking', 'change_tablebooking']
    )

    # Добавляем эти права группе 'Менеджер зала'
    manager_group.permissions.set(permissions)


class BookingsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.bookings'
    verbose_name = 'Бронирования столов'

    def ready(self):
        post_migrate.connect(create_manager_group, sender=self)
        from . import signals  # noqa: F401

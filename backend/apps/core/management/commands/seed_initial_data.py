"""
Команда для первоначального заполнения базы данных данными о ресторане.
Запускается один раз после `migrate` на новом окружении.

Использование:
    python manage.py seed_initial_data          # создать если нет
    python manage.py seed_initial_data --force  # перезаписать существующие
"""

from django.core.management.base import BaseCommand

from apps.core.models import AppVersion, RestaurantInfo


class Command(BaseCommand):
    help = "Создаёт начальные данные: RestaurantInfo и AppVersion для iOS/Android"

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Перезаписать существующие записи данными-заглушками",
        )

    def handle(self, *args, **options):
        force = options["force"]

        self._seed_restaurant_info(force)
        self._seed_app_version("ios", force)
        self._seed_app_version("android", force)

        self.stdout.write(self.style.SUCCESS("seed_initial_data завершён успешно."))

    def _seed_restaurant_info(self, force: bool) -> None:
        """Создаёт или обновляет синглтон RestaurantInfo."""
        info = RestaurantInfo.load()

        # Определяем, была ли запись только что создана (все поля пустые)
        just_created = not info.address and not info.phone

        if not just_created and not force:
            # Запись уже заполнена, пропускаем без --force
            self.stdout.write("  RestaurantInfo — уже существует, пропускаем (используйте --force для перезаписи)")
            return

        # Заполняем заглушками — администратор заменит через Django Admin
        info.address = "г. Алматы, ул. Панфилова, 98"
        info.working_hours = "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00"
        info.phone = "+7 727 000-00-00"
        info.save()

        action = "создан" if just_created else "обновлён (--force)"
        self.stdout.write(f"  RestaurantInfo — {action}")

    def _seed_app_version(self, platform: str, force: bool) -> None:
        """Создаёт или обновляет запись AppVersion для указанной платформы."""
        obj, created = AppVersion.objects.get_or_create(
            platform=platform,
            defaults={
                "min_version": "1.0.0",
                "latest_version": "1.0.0",
            },
        )

        if not created and force:
            # Перезаписываем только если явно передан --force
            obj.min_version = "1.0.0"
            obj.latest_version = "1.0.0"
            obj.save()

        action = "создана" if created else ("обновлена (--force)" if force else "уже существует, пропускаем")
        self.stdout.write(f"  AppVersion({platform}) — {action}")

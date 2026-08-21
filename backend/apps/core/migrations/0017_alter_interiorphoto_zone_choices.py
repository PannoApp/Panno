from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Категория «Интерьер» разбивается на 4 подзоны (docs/piligrim_improvements_plan.md,
    задача 4): Бар | Пещера | Ауа (ивент-спейс) | Веранда — вместо прежних
    main_hall/bar/private/terrace/other.

    Меняются только допустимые choices и default — существующие строки в БД
    со старыми кодами (main_hall/private/terrace/other) не переписываются
    автоматически: их нужно вручную переразметить на новые зоны через
    Django Admin (InteriorPhotoAdmin), так как соответствие старых зон новым
    не 1-к-1 и требует решения контент-менеджера, а не технической миграции.
    """

    dependencies = [
        ('core', '0016_restaurantinfo_concept_description_kz'),
    ]

    operations = [
        migrations.AlterField(
            model_name='interiorphoto',
            name='zone',
            field=models.CharField(
                choices=[
                    ('bar', 'Бар'),
                    ('cave', 'Пещера'),
                    ('event_space', 'Ауа'),
                    ('veranda', 'Веранда'),
                ],
                default='bar',
                max_length=20,
                verbose_name='Зона',
            ),
        ),
    ]

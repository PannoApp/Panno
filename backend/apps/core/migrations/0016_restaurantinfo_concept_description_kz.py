from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0015_remove_restaurantinfo_google_maps_link_and_more'),
    ]

    operations = [
        # Казахский перевод текста концепции для сплэша/главного экрана
        # (docs/piligrim_improvements_plan.md, задача 3). Пусто по умолчанию —
        # Flutter скрывает KZ-блок, пока перевод не заполнен через админку.
        migrations.AddField(
            model_name='restaurantinfo',
            name='concept_description_kz',
            field=models.TextField(
                verbose_name='Описание концепции (KZ)',
                blank=True,
                default='',
                help_text='Казахский перевод. Если пусто — блок на казахском не показывается.',
            ),
        ),
    ]

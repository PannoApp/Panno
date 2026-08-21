from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Точные координаты ресторана — чтобы кнопка «карты» (Google/Яндекс/Apple
    Maps) вела прямо на заведение, а не на текстовый поиск по адресу.
    Оба поля опциональны: пока не заполнены через админку, фронт
    использует адрес как менее точный фолбэк.
    """

    dependencies = [
        ('core', '0018_restaurantinfo_loyalty_recovery_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='restaurantinfo',
            name='latitude',
            field=models.FloatField(verbose_name='Широта', null=True, blank=True),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='longitude',
            field=models.FloatField(verbose_name='Долгота', null=True, blank=True),
        ),
    ]

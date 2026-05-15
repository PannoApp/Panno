from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0007_add_booking_deposit_to_restaurantinfo'),
    ]

    operations = [
        # Расширяем max_length основного поля часов работы (было 255, стало 500)
        # для поддержки многострочных расписаний вида "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00"
        migrations.AlterField(
            model_name='restaurantinfo',
            name='working_hours',
            field=models.CharField(
                max_length=500,
                verbose_name='Часы работы',
                help_text='Напр.: «Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00»',
            ),
        ),
        # Новое поле для временных изменений режима работы (праздники, спецсобытия).
        # Flutter отображает его поверх основного расписания, если не пустое.
        migrations.AddField(
            model_name='restaurantinfo',
            name='working_hours_note',
            field=models.CharField(
                verbose_name='Временное изменение режима',
                max_length=500,
                blank=True,
                default='',
                help_text='Разовое уведомление (напр.: «Закрыто 1 января»). Оставьте пустым если нет изменений.',
            ),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0002_user_last_name'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='notify_events',
            field=models.BooleanField(default=True, verbose_name='Уведомления: мероприятия'),
        ),
        migrations.AddField(
            model_name='user',
            name='notify_promotions',
            field=models.BooleanField(default=True, verbose_name='Уведомления: акции'),
        ),
        migrations.AddField(
            model_name='user',
            name='notify_closed_events',
            field=models.BooleanField(default=True, verbose_name='Уведомления: закрытые события'),
        ),
    ]

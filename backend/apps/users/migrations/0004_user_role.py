from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0003_user_notification_prefs'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='role',
            field=models.CharField(
                blank=True,
                choices=[
                    ('admin', 'Администратор'),
                    ('hall_manager', 'Менеджер зала'),
                    ('content_manager', 'Контент-менеджер'),
                ],
                max_length=20,
                verbose_name='Роль',
            ),
        ),
    ]

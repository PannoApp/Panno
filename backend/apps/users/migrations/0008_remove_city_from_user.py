from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0007_user_telegram_id'),
    ]

    operations = [
        migrations.RemoveIndex(
            model_name='user',
            name='user_city_idx',
        ),
        migrations.RemoveField(
            model_name='user',
            name='city',
        ),
    ]

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0010_user_cashback'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='user',
            name='telegram_id',
        ),
    ]

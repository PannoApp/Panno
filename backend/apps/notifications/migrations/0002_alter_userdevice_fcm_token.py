from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='userdevice',
            name='fcm_token',
            field=models.CharField(max_length=4096, unique=True, verbose_name='FCM Токен'),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='restaurantinfo',
            name='phone',
            field=models.CharField(blank=True, max_length=20, verbose_name='Телефон'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='whatsapp',
            field=models.CharField(blank=True, max_length=100, verbose_name='WhatsApp'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='telegram',
            field=models.CharField(blank=True, max_length=100, verbose_name='Telegram'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='instagram',
            field=models.CharField(blank=True, max_length=100, verbose_name='Instagram'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='visit_rules',
            field=models.TextField(blank=True, verbose_name='Правила посещения'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='privacy_policy',
            field=models.TextField(blank=True, verbose_name='Политика обработки ПД'),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='terms_of_service',
            field=models.TextField(blank=True, verbose_name='Пользовательское соглашение'),
        ),
    ]

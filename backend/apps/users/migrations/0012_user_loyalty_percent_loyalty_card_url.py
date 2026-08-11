from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0011_remove_user_telegram_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='loyalty_percent',
            field=models.CharField(blank=True, help_text='Категория гостя из CRM Remarked (поле `cat_name`, например `3%`). Не задокументировано в openapi.json — найдено эмпирически 2026-08-11 прямым запросом к /store/customer/get-info.', max_length=16, null=True, verbose_name='Процент лояльности'),
        ),
        migrations.AddField(
            model_name='user',
            name='loyalty_card_url',
            field=models.URLField(blank=True, help_text='Публичная ссылка на готовое изображение QR-кода карты лояльности из CRM Remarked (поле `card_shortcode`). Как и `loyalty_percent`, не задокументировано в openapi.json.', max_length=255, null=True, verbose_name='QR-код карты лояльности'),
        ),
    ]

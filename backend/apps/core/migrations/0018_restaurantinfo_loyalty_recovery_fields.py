from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Восстановление номера лояльности через WhatsApp (docs/piligrim_improvements_plan.md,
    задача 6, ТЗ п.4): ссылка на экране входа открывает WhatsApp-чат
    администратора с заготовленным текстом. Оба поля пусты по умолчанию —
    заполняются через админку, когда контент будет готов.
    """

    dependencies = [
        ('core', '0017_alter_interiorphoto_zone_choices'),
    ]

    operations = [
        migrations.AddField(
            model_name='restaurantinfo',
            name='loyalty_recovery_whatsapp',
            field=models.CharField(
                verbose_name='WhatsApp администратора (восстановление номера лояльности)',
                max_length=100,
                blank=True,
                default='',
                help_text='Номер в международном формате, напр. +77713333044.',
            ),
        ),
        migrations.AddField(
            model_name='restaurantinfo',
            name='loyalty_recovery_message',
            field=models.TextField(
                verbose_name='Текст обращения в WhatsApp',
                blank=True,
                default='',
                help_text='Подставляется в чат автоматически, чтобы гость не формулировал запрос сам.',
            ),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0008_remove_city_from_user'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='gender',
            field=models.CharField(
                choices=[
                    ('male', 'Мужской'),
                    ('female', 'Женский'),
                    ('not_specified', 'Не указан'),
                ],
                default='not_specified',
                max_length=20,
                verbose_name='Пол',
            ),
        ),
        migrations.AddField(
            model_name='user',
            name='email',
            field=models.EmailField(blank=True, max_length=254, verbose_name='Email'),
        ),
        migrations.AddField(
            model_name='user',
            name='birthday',
            field=models.DateField(blank=True, null=True, verbose_name='Дата рождения'),
        ),
        migrations.AddField(
            model_name='user',
            name='remarked_guest_id',
            field=models.CharField(
                blank=True,
                help_text='ID гостя (gid) в CRM Remarked. Пусто — гость ещё не синхронизирован.',
                max_length=64,
                null=True,
                verbose_name='Remarked Guest ID',
            ),
        ),
    ]

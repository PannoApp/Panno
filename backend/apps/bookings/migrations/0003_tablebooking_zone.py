from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('bookings', '0002_tablebooking_updated_at'),
    ]

    operations = [
        migrations.AddField(
            model_name='tablebooking',
            name='zone',
            field=models.CharField(
                blank=True,
                choices=[('main', 'Главный зал'), ('terrace', 'Терраса'), ('private', 'Приват')],
                max_length=50,
                null=True,
                verbose_name='Зона/зал',
            ),
        ),
    ]

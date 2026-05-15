from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('menu', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='dish',
            name='weight',
            field=models.PositiveIntegerField(blank=True, null=True, verbose_name='Вес (г)'),
        ),
        migrations.AddField(
            model_name='dish',
            name='story',
            field=models.TextField(blank=True, verbose_name='История блюда'),
        ),
    ]

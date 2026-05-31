from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0012_alter_heroslide_image_alter_interiorphoto_image'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='restaurantinfo',
            name='visit_rules',
        ),
        migrations.CreateModel(
            name='VisitRule',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=100, verbose_name='Название')),
                ('body', models.TextField(verbose_name='Текст')),
                ('order', models.PositiveIntegerField(default=0, verbose_name='Порядок')),
                ('restaurant_info', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='visit_rules',
                    to='core.restaurantinfo',
                    verbose_name='Ресторан',
                )),
            ],
            options={
                'verbose_name': 'Правило посещения',
                'verbose_name_plural': 'Правила посещения',
                'ordering': ['order'],
            },
        ),
    ]

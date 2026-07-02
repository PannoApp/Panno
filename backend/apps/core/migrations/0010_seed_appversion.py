from django.db import migrations


def seed_app_versions(apps, schema_editor):
    AppVersion = apps.get_model('core', 'AppVersion')
    for platform in ('android', 'ios'):
        AppVersion.objects.get_or_create(
            platform=platform,
            defaults={
                'min_version': '1.0.0',
                'latest_version': '1.0.0',
                'store_url': '',
            },
        )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0009_remove_restaurantinfo_hero_image_and_more'),
    ]

    operations = [
        migrations.RunPython(seed_app_versions, migrations.RunPython.noop),
    ]

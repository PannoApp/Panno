from rest_framework import serializers
from .models import RestaurantInfo, AppVersion, InteriorPhoto, HeroSlide


class HeroSlideSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroSlide
        fields = ('id', 'image', 'order')


class RestaurantInfoSerializer(serializers.ModelSerializer):
    is_open_now = serializers.SerializerMethodField()
    hero_slides = HeroSlideSerializer(many=True, read_only=True)

    class Meta:
        model = RestaurantInfo
        fields = (
            'address',
            'working_hours',
            # Временное изменение режима — пустая строка если нет активного уведомления
            'working_hours_note',
            'is_open_now',
            'tour_link',
            # Ссылки для кнопки «Построить маршрут» — передавай все, клиент покажет доступные
            'twogis_link',
            'google_maps_link',
            'yandex_maps_link',
            'phone',
            'whatsapp',
            'telegram',
            'instagram',
            'concept_description',
            'hero_slides',
            'visit_rules',
            'privacy_policy',
            'terms_of_service',
            'feedback_url',
            # Флаг депозита: если True — Flutter показывает предупреждение в форме бронирования
            'booking_deposit_required',
            'booking_deposit_note',
        )

    def get_is_open_now(self, obj) -> bool:
        return obj.is_open_now


class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model  = AppVersion
        fields = ('platform', 'min_version', 'latest_version', 'store_url', 'updated_at')


class InteriorPhotoSerializer(serializers.ModelSerializer):
    # zone_display — человекочитаемое название зоны (например "Терраса" вместо "terrace")
    zone_display = serializers.CharField(source='get_zone_display', read_only=True)

    class Meta:
        model  = InteriorPhoto
        fields = ('id', 'zone', 'zone_display', 'image', 'caption', 'order')
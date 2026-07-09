from rest_framework import serializers
from .models import RestaurantInfo, AppVersion, InteriorPhoto, HeroSlide, VisitRule


class HeroSlideSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    class Meta:
        model = HeroSlide
        fields = ('id', 'image', 'order')


class VisitRuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = VisitRule
        fields = ('title', 'body')


class RestaurantInfoSerializer(serializers.ModelSerializer):
    is_open_now = serializers.SerializerMethodField()
    hero_slides = HeroSlideSerializer(many=True, read_only=True)
    visit_rules = VisitRuleSerializer(many=True, read_only=True)

    class Meta:
        model = RestaurantInfo
        fields = (
            'address',
            'working_hours',
            # Временное изменение режима — пустая строка если нет активного уведомления
            'working_hours_note',
            'is_open_now',
            'tour_link',
            'twogis_link',
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
        )

    def get_is_open_now(self, obj) -> bool:
        return obj.is_open_now


class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model  = AppVersion
        fields = ('platform', 'min_version', 'latest_version', 'store_url', 'updated_at')


class InteriorPhotoSerializer(serializers.ModelSerializer):
    zone_display = serializers.CharField(source='get_zone_display', read_only=True)
    image = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    class Meta:
        model  = InteriorPhoto
        fields = ('id', 'zone', 'zone_display', 'image', 'caption', 'order')
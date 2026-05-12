from rest_framework import serializers
from .models import RestaurantInfo


class RestaurantInfoSerializer(serializers.ModelSerializer):
    is_open_now = serializers.SerializerMethodField()

    class Meta:
        model = RestaurantInfo
        fields = (
            'address',
            'working_hours',
            'is_open_now',
            'tour_link',
            'twogis_link',
            'phone',
            'whatsapp',
            'telegram',
            'instagram',
            'concept_description',
            'hero_image',
            'hero_video_url',
            'visit_rules',
            'privacy_policy',
            'terms_of_service',
        )

    def get_is_open_now(self, obj) -> bool:
        return obj.is_open_now
from rest_framework import serializers
from .models import RestaurantInfo

class RestaurantInfoSerializer(serializers.ModelSerializer):
    """
    Сериализатор для выдачи статической информации о ресторане.
    """
    class Meta:
        model = RestaurantInfo
        fields = (
            'address',
            'working_hours',
            'tour_link',
            'twogis_link',
        )
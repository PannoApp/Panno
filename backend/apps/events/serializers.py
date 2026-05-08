from rest_framework import serializers
from .models import Event, News

class EventSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели мероприятий.
    """
    class Meta:
        model = Event
        fields = (
            'id', 
            'title', 
            'description', 
            'date_time', 
            'image', 
            'is_active', 
            'created_at'
        )

class NewsSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели новостей.
    """
    class Meta:
        model = News
        fields = (
            'id', 
            'title', 
            'content', 
            'image', 
            'created_at'
        )
from rest_framework import serializers
from .models import Category, Tag, Allergen, Dish


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ('id', 'name', 'order')

class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ('id', 'name')

class AllergenSerializer(serializers.ModelSerializer):
    class Meta:
        model = Allergen
        fields = ('id', 'name')

class DishSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    tags = TagSerializer(many=True, read_only=True)
    allergens = AllergenSerializer(many=True, read_only=True)

    # Абсолютный URL обработанного видео; None — если видео ещё не готово
    video_url = serializers.SerializerMethodField()

    def get_video_url(self, obj):
        if obj.video_processed:
            request = self.context.get('request')
            return request.build_absolute_uri(obj.video_processed.url) if request else obj.video_processed.url
        return None

    class Meta:
        model = Dish
        fields = (
            'id', 'name', 'description', 'price',
            'category', 'tags', 'allergens',
            'image', 'video', 'video_url', 'video_status',
            'weight', 'story', 'is_active'
        )
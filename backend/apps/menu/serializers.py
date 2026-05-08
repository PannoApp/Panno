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
        models = Allergen
        fields = ('id', 'name')

class DishSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    tags = TagSerializer(many=True, read_only=True)
    allergens = AllergenSerializer(many=True, read_only=True)

    class Meta:
        model = Dish
        fields = (
            'id', 'name', 'description', 'price', 
            'category', 'tags', 'allergens', 
            'image', 'video', 'is_active'
        )
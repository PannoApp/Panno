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

    image = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

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
            'image', 'video_url', 'video_status',
            'weight', 'story', 'is_active'
        )


class StaffDishSerializer(serializers.ModelSerializer):
    category = serializers.PrimaryKeyRelatedField(queryset=Category.objects.all())
    tags = serializers.PrimaryKeyRelatedField(many=True, queryset=Tag.objects.all(), required=False)
    allergens = serializers.PrimaryKeyRelatedField(many=True, queryset=Allergen.objects.all(), required=False)
    image = serializers.ImageField(required=False)
    image_url = serializers.SerializerMethodField()
    video = serializers.FileField(required=False, allow_null=True, allow_empty_file=False)
    video_url = serializers.SerializerMethodField()
    video_status = serializers.CharField(read_only=True)

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    def get_video_url(self, obj):
        if not obj.video_processed:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.video_processed.url) if request else obj.video_processed.url

    def validate_video(self, value):
        allowed = {'video/mp4', 'video/quicktime', 'video/x-m4v'}
        if value is not None and value.content_type not in allowed:
            raise serializers.ValidationError('Поддерживаются только форматы MP4 и MOV.')
        return value

    def validate(self, attrs):
        if self.instance is None and not attrs.get('image'):
            raise serializers.ValidationError({'image': 'Фото обязательно при создании блюда.'})
        return attrs

    class Meta:
        model = Dish
        fields = (
            'id', 'name', 'description', 'price',
            'category', 'tags', 'allergens',
            'image', 'image_url',
            'video', 'video_url', 'video_status',
            'weight', 'story', 'is_active',
        )
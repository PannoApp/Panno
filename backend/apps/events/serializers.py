from rest_framework import serializers
from .models import Event, News, EventReservation, EventPhotoReport


class EventPhotoReportSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    class Meta:
        model = EventPhotoReport
        fields = ('id', 'image', 'order')


class EventSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели мероприятий.
    """
    image = serializers.SerializerMethodField()
    has_photo_report = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    def get_has_photo_report(self, obj):
        return obj.photo_reports.exists()

    class Meta:
        model = Event
        fields = (
            'id',
            'title',
            'description',
            'date_time',
            'image',
            'format',
            'price',
            'is_active',
            'created_at',
            'has_photo_report',
            'max_places',
            'occupied_places',
        )

class NewsSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели новостей.
    """
    image = serializers.SerializerMethodField()

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    class Meta:
        model = News
        fields = (
            'id',
            'title',
            'content',
            'image',
            'created_at'
        )

class EventReservationSerializer(serializers.ModelSerializer):
    """
    Сериализатор для создания и просмотра записей на мероприятия.
    """
    #Добавляем вложенный сериализатор для отображения деталей мероприятия в истории
    event_details = EventSerializer(source='event', read_only=True)

    class Meta:
        model = EventReservation
        fields = (
            'id',
            'event',
            'event_details',
            'guests_count',
            'created_at'
        )
        # Поле user будет заполняться автоматически из запроса (request.user)
        read_only_fields = ('id', 'created_at')
    
    def validate(self, data):
        """
        Проверка уникальности записи и наличия свободных мест на мероприятии.
        """
        user = self.context['request'].user
        event = data['event']
        guests_count = data.get('guests_count', 1)

        # Проверка повторной записи
        if EventReservation.objects.filter(user=user, event=event).exists():
            raise serializers.ValidationError("Вы уже записаны на это мероприятие.")

        # Проверка вместимости (если установлен лимит мест)
        if event.max_places > 0:
            occupied = event.occupied_places
            if occupied + guests_count > event.max_places:
                remaining = max(0, event.max_places - occupied)
                raise serializers.ValidationError(
                    f"Недостаточно свободных мест. Осталось мест: {remaining}."
                )

        return data


class EventReservationStaffSerializer(EventReservationSerializer):
    """Сериализатор для менеджера зала: добавляет имя и телефон гостя из профиля."""
    guest_name  = serializers.SerializerMethodField()
    guest_phone = serializers.CharField(source='user.phone', read_only=True, default=None)

    class Meta(EventReservationSerializer.Meta):
        fields = EventReservationSerializer.Meta.fields + ('guest_name', 'guest_phone')

    def get_guest_name(self, obj):
        if not obj.user:
            return None
        full = f"{obj.user.first_name} {obj.user.last_name}".strip()
        return full or obj.user.phone


class StaffEventSerializer(serializers.ModelSerializer):
    image      = serializers.ImageField(required=False)
    image_url  = serializers.SerializerMethodField()
    format     = serializers.CharField(default='open')
    price      = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)
    is_active  = serializers.BooleanField(default=True)
    max_places = serializers.IntegerField(default=0, required=False)

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    def validate_format(self, value):
        allowed = ['open', 'closed']
        if value not in allowed:
            raise serializers.ValidationError(
                f"Недопустимое значение. Допустимые значения: {allowed}."
            )
        return value

    def validate(self, data):
        # при создании обложка обязательна
        if self.instance is None and not data.get('image'):
            raise serializers.ValidationError({'image': 'Обложка обязательна при создании мероприятия.'})
        return data

    class Meta:
        model  = Event
        fields = (
            'id',
            'title',
            'description',
            'date_time',
            'image',
            'image_url',
            'format',
            'price',
            'is_active',
            'max_places',
            'created_at',
            'occupied_places',
        )
        read_only_fields = ('id', 'created_at', 'occupied_places')


class StaffPhotoReportCreateSerializer(serializers.ModelSerializer):
    """Принимает image (файл) и опциональный order при загрузке фото в фотоотчёт."""

    class Meta:
        model = EventPhotoReport
        fields = ('id', 'image', 'order')
        read_only_fields = ('id',)

    def to_representation(self, instance):
        return EventPhotoReportSerializer(instance, context=self.context).data


class StaffNewsSerializer(serializers.ModelSerializer):
    image     = serializers.ImageField(required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    class Meta:
        model  = News
        fields = (
            'id',
            'title',
            'content',
            'image',
            'image_url',
            'created_at',
        )
        read_only_fields = ('id', 'created_at')
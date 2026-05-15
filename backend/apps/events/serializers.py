from rest_framework import serializers
from .models import Event, News, EventReservation

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
            'format',
            'price',
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
        Проверка, что пользователь не записывается на одно и то же событие дважды.
        """
        user = self.context['request'].user
        event = data['event']
        if EventReservation.objects.filter(user=user, event=event).exists():
            raise serializers.ValidationError("Вы уже записаны на это мероприятие.")
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
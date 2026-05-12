from rest_framework import serializers
from django.core.validators import MaxValueValidator, MinValueValidator
from .models import TableBooking


class TableBookingSerializer(serializers.ModelSerializer):
    guests_count = serializers.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(50)]
    )

    class Meta:
        model = TableBooking
        fields = ('id', 'guest_name', 'phone', 'date', 'time', 'guests_count', 'zone', 'comment', 'status', 'created_at')
        read_only_fields = ('id', 'status', 'created_at')


class TableBookingStaffSerializer(serializers.ModelSerializer):
    """Сериализатор для менеджера зала: видит все поля, может менять статус."""
    guests_count = serializers.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(50)]
    )
    user_phone = serializers.CharField(source='user.phone', read_only=True, default=None)

    class Meta:
        model = TableBooking
        fields = (
            'id', 'user', 'user_phone',
            'guest_name', 'phone', 'date', 'time', 'guests_count', 'zone', 'comment',
            'status', 'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'user', 'user_phone', 'created_at', 'updated_at')

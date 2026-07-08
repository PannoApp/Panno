from rest_framework import serializers
from django.core.validators import MaxValueValidator, MinValueValidator
import re
from apps.core.models import RestaurantInfo
from .models import TableBooking

_PHONE_RE = re.compile(r'^\+[1-9]\d{9,14}$')


class TableBookingSerializer(serializers.ModelSerializer):
    guests_count = serializers.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(50)]
    )
    phone = serializers.CharField(max_length=20)

    def validate_phone(self, value):
        if not _PHONE_RE.match(value):
            raise serializers.ValidationError(
                "Номер телефона должен быть в формате: '+77001234567'. До 15 цифр."
            )
        return value

    def validate(self, attrs):
        date = attrs.get('date')
        time = attrs.get('time')
        # Проверяем только когда оба поля прошли собственную валидацию — при
        # отсутствующем/невалидном date или time сюда не дойдём, DRF уже
        # соберёт field-level ошибки раньше object-level validate().
        if date is not None and time is not None:
            is_open = RestaurantInfo.load().is_open_at(date.weekday(), time)
            # None — working_hours пуст/не распознан, не блокируем бронь
            if is_open is False:
                raise serializers.ValidationError({
                    'time': ['К сожалению, ресторан не работает в это время. Пожалуйста, выберите другое время.'],
                })
        return attrs

    class Meta:
        model = TableBooking
        fields = ('id', 'guest_name', 'phone', 'date', 'time', 'guests_count', 'zone', 'comment', 'status', 'created_at')
        read_only_fields = ('id', 'status', 'created_at')


class AvailabilityQuerySerializer(serializers.Serializer):
    date = serializers.DateField()
    guests = serializers.IntegerField(validators=[MinValueValidator(1), MaxValueValidator(50)])


class AvailabilitySlotSerializer(serializers.Serializer):
    """Только для схемы ответа (drf-spectacular) — сам ответ отдаётся как plain dict."""
    time = serializers.CharField()
    is_free = serializers.BooleanField()
    tables_count = serializers.IntegerField()


class AvailabilityResponseSerializer(serializers.Serializer):
    date = serializers.DateField()
    guests_count = serializers.IntegerField()
    slots = AvailabilitySlotSerializer(many=True)

from rest_framework import serializers
from django.core.validators import MaxValueValidator, MinValueValidator
import re
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

    class Meta:
        model = TableBooking
        fields = ('id', 'guest_name', 'phone', 'date', 'time', 'guests_count', 'zone', 'comment', 'status', 'created_at')
        read_only_fields = ('id', 'status', 'created_at')

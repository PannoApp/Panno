from rest_framework import serializers
from django.core.validators import MaxValueValidator, MinValueValidator
from .models import TableBooking


class TableBookingSerializer(serializers.ModelSerializer):
    guests_count = serializers.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(50)]
    )

    class Meta:
        model = TableBooking
        fields = ('id', 'guest_name', 'date', 'time', 'guests_count', 'zone', 'comment', 'status', 'created_at')
        read_only_fields = ('id', 'status', 'created_at')

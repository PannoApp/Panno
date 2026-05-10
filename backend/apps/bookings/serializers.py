from rest_framework import serializers
from .models import TableBooking


class TableBookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = TableBooking
        fields = ('id', 'guest_name', 'date', 'time', 'guests_count', 'comment', 'status', 'created_at')
        read_only_fields = ('id', 'status', 'created_at')

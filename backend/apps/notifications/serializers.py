from rest_framework import serializers
from .models import UserDevice


class UserDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDevice
        fields = ['fcm_token']
        # Unique validation is intentionally disabled: the view uses update_or_create
        # to re-link an existing token to the current user (account switch flow).
        extra_kwargs = {
            'fcm_token': {'validators': []}
        }


SEGMENT_CHOICES = ['all', 'last_visit_days', 'participated_in_event', 'registered_after']
CATEGORY_CHOICES = ['events', 'promotions', 'closed_events']


class BulkPushSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255)
    body = serializers.CharField()
    data = serializers.DictField(child=serializers.CharField(), required=False, default=dict)
    category = serializers.ChoiceField(choices=CATEGORY_CHOICES, required=False, allow_null=True, default=None)
    segment = serializers.ChoiceField(choices=SEGMENT_CHOICES, default='all')
    # Параметры сегментов
    last_visit_days = serializers.IntegerField(required=False, min_value=1, help_text="Только пользователи, чьи брони были в последние N дней")
    event_id = serializers.IntegerField(required=False, help_text="Только участники указанного мероприятия")
    registered_after = serializers.DateField(required=False, help_text="Только пользователи, зарегистрированные после даты (YYYY-MM-DD)")

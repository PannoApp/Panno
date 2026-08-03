from rest_framework import serializers
from .models import OWN_CHANNEL_DATA_KEY, OWN_CHANNEL_DATA_VALUE, PushReceipt, UserDevice


class UserDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDevice
        fields = ['fcm_token']
        # Unique validation is intentionally disabled: the view uses update_or_create
        # to re-link an existing token to the current user (account switch flow).
        extra_kwargs = {
            'fcm_token': {'validators': []}
        }


PUSH_RECEIPT_CONTEXT_CHOICES = ['foreground', 'opened_app', 'background']


class PushReceiptSerializer(serializers.Serializer):
    """
    Публичный (без JWT) вход для лога "push реально получен на устройстве" —
    см. PushReceipt в models.py. Без авторизации намеренно: фоновый обработчик
    FCM (onBackgroundMessage) работает в отдельном изоляте с ограниченным
    временем на выполнение, и не может надёжно читать/обновлять JWT — вместо
    этого пользователь резолвится по fcm_token (уже уникален и известен нам
    из UserDevice).
    """
    fcm_token = serializers.CharField(max_length=4096)
    title = serializers.CharField(max_length=255, required=False, allow_blank=True, default='')
    body = serializers.CharField(required=False, allow_blank=True, default='')
    data = serializers.DictField(child=serializers.CharField(), required=False, default=dict)
    context = serializers.ChoiceField(choices=PUSH_RECEIPT_CONTEXT_CHOICES)

    def create(self, validated_data):
        fcm_token = validated_data['fcm_token']
        data = validated_data.get('data') or {}
        device = UserDevice.objects.filter(fcm_token=fcm_token).only('user_id').first()
        return PushReceipt.objects.create(
            user_id=device.user_id if device else None,
            fcm_token=fcm_token,
            title=validated_data.get('title', ''),
            body=validated_data.get('body', ''),
            data=data,
            context=validated_data['context'],
            is_own_channel=data.get(OWN_CHANNEL_DATA_KEY) == OWN_CHANNEL_DATA_VALUE,
        )


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


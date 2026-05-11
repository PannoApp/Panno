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

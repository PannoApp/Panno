from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.core.validators import RegexValidator

User = get_user_model()

phone_regex = RegexValidator(
    regex=r'^\+[1-9]\d{9,14}$',
    message="Номер телефона должен быть в формате: '+77001234567'. Допускается до 15 символов."
)

otp_regex = RegexValidator(
    regex=r'^\d{4}$',
    message="Код должен состоять из 4 цифр."
)

class RequestSMSSerializer(serializers.Serializer):
    phone = serializers.CharField(
        max_length=15,
        required=True,
        validators=[phone_regex],
        help_text="Номер телефона (например, +77001234567)"
    )

class VerifySMSSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15, validators=[phone_regex])
    otp = serializers.CharField(
        max_length=4,
        min_length=4,
        validators=[otp_regex],
        help_text="4-значный цифровой код из SMS"
    )

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id', 'phone', 'first_name', 'last_name',
            # Город — Flutter передаёт при наличии разрешения на геолокацию
            'city',
            'notifications_enabled',
            'notify_events', 'notify_promotions', 'notify_closed_events',
        )
        read_only_fields = ('id', 'phone')
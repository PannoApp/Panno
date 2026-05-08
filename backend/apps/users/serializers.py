from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.core.validators import RegexValidator

User = get_user_model()

# Создаем правило: строка должна начинаться с '+' и содержать от 10 до 14 цифр после него.
phone_regex = RegexValidator(
    regex=r'^\+[1-9]\d{9,14}$',
    message="Номер телефона должен быть в формате: '+77001234567'. Допускается до 15 символов."
)

class RequestSMSSerializer(serializers.Serializer):
    phone = serializers.CharField(
        max_length=15,
        required=True,
        validators=[phone_regex], # Подключаем валидатор
        help_text="Номер телефона (например, +77001234567)"
    )

class VerifySMSSerializer(serializers.Serializer):
    phone = serializers.CharField(
        max_length=15,
        validators=[phone_regex]  # Подключаем валидатор
        )
    otp = serializers.CharField(
        max_length=4, 
        min_length=4, 
        help_text="4-значный код из SMS"
    )

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'phone', 'first_name', 'last_name')
        # Делаем id и phone только для чтения. 
        # Смена номера телефона обычно требует отдельной логики с подтверждением по SMS.
        read_only_fields = ('id', 'phone')
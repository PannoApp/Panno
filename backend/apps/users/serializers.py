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

class LoyaltyLoginSerializer(serializers.Serializer):
    """
    Вход по номеру телефона + номеру участника лояльности (ТЗ по входу, п.2),
    вместо SMS-кода. Только для гостей, уже существующих в Remarked — см.
    LoyaltyLoginView.
    """
    phone = serializers.CharField(max_length=15, validators=[phone_regex])
    member_number = serializers.CharField(
        max_length=32,
        min_length=1,
        trim_whitespace=True,
        help_text="Номер участника программы лояльности",
    )


class LoyaltyRegisterSerializer(serializers.Serializer):
    """
    Регистрация нового гостя лояльности (ТЗ по входу, п.1) — состав полей
    повторяет форму выдачи карты в Apple Wallet. Только phone/first_name/
    gender обязательны у Remarked (см. openapi.json, /store/customer/create,
    requestBody.required) — остальное можно пропустить.
    """
    phone = serializers.CharField(max_length=15, validators=[phone_regex])
    first_name = serializers.CharField(max_length=150, trim_whitespace=True)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    birthday = serializers.DateField(required=False, allow_null=True)
    gender = serializers.ChoiceField(
        choices=[User.GENDER_MALE, User.GENDER_FEMALE, User.GENDER_NOT_SPECIFIED],
        default=User.GENDER_NOT_SPECIFIED,
    )


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(
        help_text="Refresh-токен, который нужно отозвать"
    )


class UserProfileSerializer(serializers.ModelSerializer):
    # read_only=True обязателен на явно объявленном поле — Meta.read_only_fields
    # не распространяется на поля, объявленные вне Meta.
    role = serializers.CharField(default="", read_only=True)

    class Meta:
        model = User
        fields = (
            'id', 'phone', 'first_name', 'last_name',
            'gender', 'email', 'birthday',
            'notifications_enabled',
            'notify_events', 'notify_promotions', 'notify_closed_events',
            'is_staff', 'role', 'cashback', 'loyalty_percent', 'loyalty_card_url', 'date_joined',
        )
        read_only_fields = (
            'id', 'phone', 'is_staff', 'role', 'cashback',
            'loyalty_percent', 'loyalty_card_url', 'date_joined',
        )
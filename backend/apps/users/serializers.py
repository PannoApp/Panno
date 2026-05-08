from rest_framework import serializers

class RequestSMSSerializer(serializers.Serializer):
    phone = serializers.CharField(
        max_length=15,
        required=True,
        help_text="Номер телефона (например, +77001234567)"
    )

class VerifySMSSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(
        max_length=4, 
        min_length=4, 
        help_text="4-значный код из SMS"
    )
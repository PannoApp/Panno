from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import ScopedRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model

from .serializers import RequestSMSSerializer, VerifySMSSerializer, UserProfileSerializer
from .services import SMSService

User = get_user_model()


class RequestSMSView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sms_request'

    def post(self, request):
        serializer = RequestSMSSerializer(data=request.data)
        if serializer.is_valid():
            phone = serializer.validated_data['phone']
            if SMSService.send_sms(phone):
                return Response({'message': 'SMS код отправлен.'})
            return Response(
                {'error': 'Ошибка при отправке SMS.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VerifySMSView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sms_verify'

    def post(self, request):
        serializer = VerifySMSSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data['phone']
        otp = serializer.validated_data['otp']

        if not SMSService.verify_otp(phone, otp):
            return Response(
                {'error': 'Неверный или просроченный код.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user, created = User.objects.get_or_create(phone=phone)
        refresh = RefreshToken.for_user(user)

        return Response({
            'message': 'Успешная авторизация',
            'is_new_user': created,
            'user_id': user.id,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })


class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

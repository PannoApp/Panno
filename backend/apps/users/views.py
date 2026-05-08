from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model

from .serializers import RequestSMSSerializer, VerifySMSSerializer
from .services import SMSService

User = get_user_model()

class RequestSMSView(APIView):
    """
    Эндпоинт для запроса SMS кода.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RequestSMSSerializer(data=request.data)
        if serializer.is_valid():
            phone = serializer.validated_data['phone']
            
            # Генерируем и "отправляем" код (в dev-режиме упадет в консоль)
            success = SMSService.send_sms(phone)
            
            if success:
                return Response({"message": "SMS код отправлен."}, status=status.HTTP_200_OK)
            return Response({"error": "Ошибка при отправке SMS."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VerifySMSView(APIView):
    """
    Эндпоинт для проверки SMS кода и выдачи JWT токенов.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifySMSSerializer(data=request.data)
        if serializer.is_valid():
            phone = serializer.validated_data['phone']
            otp = serializer.validated_data['otp']

            # Проверяем код через сервис
            is_valid = SMSService.verify_otp(phone, otp)
            
            if is_valid:
                # get_or_create вернет пользователя, а если его нет - создаст
                user, created = User.objects.get_or_create(phone=phone)
                
                # SimpleJWT: генерируем токены для пользователя
                refresh = RefreshToken.for_user(user)
                
                return Response({
                    "message": "Успешная авторизация",
                    "is_new_user": created,
                    "user_id": user.id,
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                }, status=status.HTTP_200_OK)
            
            return Response({"error": "Неверный или просроченный код."}, status=status.HTTP_400_BAD_REQUEST)
            
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
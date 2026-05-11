from rest_framework import status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import UserDevice
from .serializers import UserDeviceSerializer

class RegisterDeviceView(views.APIView):
    """
    API для регистрации или обновления FCM токена устройства пользователя.
    """
    # Доступ только для авторизованных пользователей (нужен токен доступа)
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = UserDeviceSerializer(data=request.data)
        
        if serializer.is_valid():
            fcm_token = serializer.validated_data['fcm_token']
            
            # update_or_create ищет запись по fcm_token. 
            # Если находит — обновляет поле user на текущего. 
            # Если не находит — создает новую запись.
            device, created = UserDevice.objects.update_or_create(
                fcm_token=fcm_token,
                defaults={'user': request.user}
            )
            
            if created:
                return Response(
                    {"message": "Устройство успешно зарегистрировано."}, 
                    status=status.HTTP_201_CREATED
                )
            
            return Response(
                {"message": "Токен устройства обновлен (перепривязан)."}, 
                status=status.HTTP_200_OK
            )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
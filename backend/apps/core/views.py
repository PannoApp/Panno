from rest_framework import generics
from rest_framework.permissions import AllowAny
from .models import RestaurantInfo
from .serializers import RestaurantInfoSerializer

class RestaurantInfoView(generics.RetrieveAPIView):
    """
    Эндпоинт для получения статической информации о ресторане.
    Доступен всем (без авторизации).
    """
    serializer_class = RestaurantInfoSerializer
    permission_classes = [AllowAny]

    def get_object(self):
        # Метод load() сам найдет запись с pk=1 или создаст пустую
        return RestaurantInfo.load()
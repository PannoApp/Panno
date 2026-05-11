from rest_framework import generics
from rest_framework.permissions import AllowAny
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse
from .models import RestaurantInfo
from .serializers import RestaurantInfoSerializer


@extend_schema(
    tags=['Core'],
    summary='Информация о ресторане',
    description=(
        'Возвращает статическую публичную информацию о ресторане: адрес, часы работы '
        'и ссылки на 3D-тур и карту 2GIS.\n\n'
        'Доступен без авторизации.'
    ),
    responses={
        200: OpenApiResponse(
            response=RestaurantInfoSerializer,
            description='Информация о ресторане',
            examples=[
                OpenApiExample(
                    'Пример',
                    value={
                        'address': 'г. Алматы, ул. Панфилова, 98',
                        'working_hours': 'Пн–Вс: 12:00–00:00',
                        'tour_link': 'https://tour.example.com/panno',
                        'twogis_link': 'https://2gis.kz/almaty/firm/123456789',
                    },
                    response_only=True,
                )
            ],
        ),
    },
)
class RestaurantInfoView(generics.RetrieveAPIView):
    """
    Эндпоинт для получения статической информации о ресторане.
    Доступен всем (без авторизации).
    """
    serializer_class = RestaurantInfoSerializer
    permission_classes = [AllowAny]

    def get_object(self):
        return RestaurantInfo.load()

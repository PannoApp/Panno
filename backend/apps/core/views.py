from django.core.cache import cache
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse
from .models import RestaurantInfo, AppVersion, InteriorPhoto
from .serializers import RestaurantInfoSerializer, AppVersionSerializer, InteriorPhotoSerializer
from utils.cache import safe_cache_get_or_set, safe_cache_get, safe_cache_set

# TTL для статичных данных, которые меняются редко (раз в неделю и реже)
_CACHE_1H = 3600


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
        # Синглтон меняется крайне редко — кэшируем на 1 час.
        # Инвалидация через post_save-сигнал в apps/core/signals.py.
        # При недоступном Redis — fallback к прямому запросу в БД.
        return safe_cache_get_or_set('restaurant_info', RestaurantInfo.load, timeout=_CACHE_1H)


class AppVersionView(generics.RetrieveAPIView):
    """
    GET /api/v1/core/app-version/?platform=ios|android

    Возвращает минимальную и последнюю версию приложения для заданной платформы.
    Доступен без авторизации.
    """
    serializer_class   = AppVersionSerializer
    permission_classes = [AllowAny]

    def get_object(self):
        platform = self.request.query_params.get('platform', '')
        return get_object_or_404(AppVersion, platform=platform)


@extend_schema(
    tags=['Core'],
    summary='Галерея фотографий интерьера',
    description=(
        'Возвращает фотографии интерьера ресторана, сгруппированные по зонам.\n\n'
        'Доступен без авторизации.\n\n'
        '**Зоны:** `main_hall` — Главный зал, `bar` — Бар, '
        '`private` — Приватная комната, `terrace` — Терраса, `other` — Другое.'
    ),
    responses={200: InteriorPhotoSerializer(many=True)},
)
class InteriorPhotoListView(generics.ListAPIView):
    """
    Список фотографий интерьера для вкладки «Интерьер/3D-тур».
    Без авторизации, без пагинации — фотографий обычно немного (10–30 штук).
    """
    serializer_class   = InteriorPhotoSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return InteriorPhoto.objects.all().order_by('zone', 'order')

    def list(self, request, *args, **kwargs):
        # Галерея меняется редко — кэшируем на 1 час.
        # Инвалидация через post_save/post_delete-сигнал в apps/core/signals.py.
        # При недоступном Redis — fallback к прямому запросу в БД.
        cached = safe_cache_get('interior_photos')
        if cached is not None:
            return Response(cached)
        response = super().list(request, *args, **kwargs)
        safe_cache_set('interior_photos', response.data, timeout=_CACHE_1H)
        return response

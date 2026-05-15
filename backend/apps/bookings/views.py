from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from utils.idempotency import IdempotencyMixin
from utils.pagination import StandardPagination
from .models import TableBooking
from .serializers import TableBookingSerializer


_error_401 = OpenApiResponse(description='Токен не передан или недействителен')

_pagination_params = [
    OpenApiParameter(
        name='page',
        type=OpenApiTypes.INT,
        location=OpenApiParameter.QUERY,
        description='Номер страницы',
        required=False,
    ),
    OpenApiParameter(
        name='page_size',
        type=OpenApiTypes.INT,
        location=OpenApiParameter.QUERY,
        description='Количество записей на странице (по умолчанию 20, максимум 100)',
        required=False,
    ),
]


@extend_schema(tags=['Bookings'])
class TableBookingListCreateView(IdempotencyMixin, generics.ListCreateAPIView):
    serializer_class = TableBookingSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination

    @extend_schema(
        summary='Список моих бронирований столов',
        description=(
            'Возвращает все бронирования текущего авторизованного пользователя, '
            'отсортированные по дате и времени визита (ближайшие первыми).'
        ),
        parameters=_pagination_params,
        responses={
            200: TableBookingSerializer(many=True),
            401: _error_401,
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        summary='Создать бронирование стола',
        description=(
            'Создаёт новое бронирование стола для текущего авторизованного пользователя.\n\n'
            'Статус нового бронирования автоматически устанавливается в `pending` '
            '(ожидает подтверждения).\n\n'
            '**Ограничения:** количество гостей от 1 до 50.'
        ),
        request=TableBookingSerializer,
        responses={
            201: TableBookingSerializer,
            400: OpenApiResponse(
                description='Ошибка валидации входных данных',
                examples=[
                    OpenApiExample(
                        'Превышен лимит гостей',
                        value={'guests_count': ['Убедитесь, что это значение меньше либо равно 50.']},
                    ),
                    OpenApiExample(
                        'Обязательное поле',
                        value={'guest_name': ['Обязательное поле.']},
                    ),
                ],
            ),
            401: _error_401,
        },
        examples=[
            OpenApiExample(
                'Бронирование на 4 гостей',
                value={
                    'guest_name': 'Алихан Сейткали',
                    'date': '2026-06-15',
                    'time': '19:30:00',
                    'guests_count': 4,
                    'comment': 'Аллергия на орехи, нужен детский стул',
                },
                request_only=True,
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return TableBooking.objects.none()
        return TableBooking.objects.filter(user=self.request.user).order_by('-date', '-time')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

import logging

from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from utils.cache import safe_cache_get, safe_cache_set
from utils.idempotency import IdempotencyMixin
from utils.pagination import StandardPagination
from apps.remarked.exceptions import RemarkedAPIError
from .models import TableBooking
from .serializers import (
    AvailabilityQuerySerializer,
    AvailabilityResponseSerializer,
    AvailableTablesQuerySerializer,
    BookingTableSerializer,
    BookingZoneSerializer,
    TableBookingSerializer,
)
from .services import check_availability, list_available_tables, list_zones

logger = logging.getLogger(__name__)


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
        booking = serializer.save(user=self.request.user)
        from .tasks import create_reserve_in_remarked
        try:
            create_reserve_in_remarked.delay(booking.id)
        except Exception:
            logger.error(
                "Celery broker unavailable — create_reserve_in_remarked not queued: booking=%s",
                booking.id,
            )


_error_503 = OpenApiResponse(
    description='Проверка занятости временно недоступна (Remarked не отвечает)',
    examples=[OpenApiExample('Remarked недоступен', value={'detail': 'Проверка занятости временно недоступна'})],
)

_availability_cache_key_fmt = 'reserve_availability:{date}:{guests}:{zone}'
_zones_cache_key = 'reserve_zones'


@extend_schema(tags=['Bookings'])
class BookingAvailabilityView(APIView):
    """
    Публичная проверка занятости на дату, опционально — по конкретному залу
    (см. BookingZonesView и apps/bookings/services.py::get_rooms). Ничего не
    создаёт и не меняет — обычный просмотр, как /api/v1/menu/ или
    /api/v1/core/info/.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary='Проверить доступность на дату',
        description=(
            'Возвращает список получасовых слотов на указанную дату с флагом занятости.\n\n'
            'Если передан `zone_id` (см. `/bookings/zones/`) — занятость считается только '
            'по столам этого зала, иначе — по всему ресторану.\n\n'
            'Результат кешируется на 60 секунд. Недоступность Remarked не блокирует '
            'создание брони — эндпоинт лишь подсказка для UI, при 503 клиент может '
            'продолжить бронирование без проверки.'
        ),
        parameters=[
            OpenApiParameter(name='date', type=OpenApiTypes.DATE, location=OpenApiParameter.QUERY, required=True, description='Дата визита, YYYY-MM-DD'),
            OpenApiParameter(name='guests', type=OpenApiTypes.INT, location=OpenApiParameter.QUERY, required=True, description='Количество гостей (1–50)'),
            OpenApiParameter(name='zone_id', type=OpenApiTypes.INT, location=OpenApiParameter.QUERY, required=False, description='ID зала из /bookings/zones/ (опционально)'),
        ],
        responses={
            200: AvailabilityResponseSerializer,
            400: OpenApiResponse(description='Ошибка валидации параметров'),
            503: _error_503,
        },
        examples=[
            OpenApiExample(
                'Пример ответа',
                value={
                    'date': '2026-07-15',
                    'guests_count': 2,
                    'slots': [
                        {'time': '12:00:00', 'is_free': False, 'tables_count': 0},
                        {'time': '14:00:00', 'is_free': True, 'tables_count': 13},
                    ],
                },
                response_only=True,
            ),
        ],
    )
    def get(self, request, *args, **kwargs):
        query = AvailabilityQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        date = query.validated_data['date']
        guests = query.validated_data['guests']
        zone_id = query.validated_data.get('zone_id')

        cache_key = _availability_cache_key_fmt.format(date=date.isoformat(), guests=guests, zone=zone_id or '')
        slots = safe_cache_get(cache_key)
        if slots is None:
            try:
                slots = check_availability(date.isoformat(), guests, zone_id=zone_id)
            except RemarkedAPIError:
                logger.warning("Availability check failed: date=%s guests=%s zone_id=%s", date, guests, zone_id, exc_info=True)
                return Response({'detail': 'Проверка занятости временно недоступна'}, status=503)
            safe_cache_set(cache_key, slots, timeout=60)

        return Response({'date': date, 'guests_count': guests, 'slots': slots})


@extend_schema(tags=['Bookings'])
class BookingZonesView(APIView):
    """
    Список реальных залов ресторана из Remarked (id + название), для пикера
    зала в форме бронирования — см. apps/bookings/services.py::list_zones.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary='Список залов ресторана',
        description=(
            'Возвращает реальные залы ресторана (id и название) из Remarked. '
            'Результат кешируется на час. При недоступности Remarked возвращает '
            'пустой список — клиент должен считать выбор зала необязательным.'
        ),
        responses={
            200: BookingZoneSerializer(many=True),
        },
        examples=[
            OpenApiExample(
                'Пример ответа',
                value=[{'id': 304, 'name': 'Зал 1'}, {'id': 305, 'name': 'Зал 2'}],
                response_only=True,
            ),
        ],
    )
    def get(self, request, *args, **kwargs):
        zones = safe_cache_get(_zones_cache_key)
        if zones is None:
            try:
                zones = list_zones()
            except RemarkedAPIError:
                logger.warning("Zones fetch failed", exc_info=True)
                return Response([])
            safe_cache_set(_zones_cache_key, zones, timeout=60 * 60)
        return Response(zones)


_tables_cache_key_fmt = 'reserve_tables:{date}:{time}:{guests}:{zone}'


@extend_schema(tags=['Bookings'])
class BookingTablesView(APIView):
    """
    Список свободных столов конкретного зала на точные дату/время/кол-во
    гостей — для пикера конкретного стола в форме бронирования (появляется
    после выбора зала, см. BookingZonesView). Ничего не создаёт и не меняет.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary='Список свободных столов зала на точное время',
        description=(
            'Возвращает свободные столы конкретного зала (`zone_id` из '
            '`/bookings/zones/`) на точные дату/время/кол-во гостей — с '
            'человеческим номером стола и вместимостью.\n\n'
            'Результат кешируется на 60 секунд. Пустой список `200 []` — '
            'подтверждённый Remarked факт: в зале нет свободных столов на '
            'эти дату/время/кол-во гостей (клиент должен не позволять '
            'бронирование в этом зале). При недоступности Remarked — `503`, '
            'а не пустой список: в этом случае реальная занятость неизвестна, '
            'и клиент не должен блокировать бронирование по этой причине '
            '(та же семантика, что у `/bookings/availability/`).'
        ),
        parameters=[
            OpenApiParameter(name='date', type=OpenApiTypes.DATE, location=OpenApiParameter.QUERY, required=True, description='Дата визита, YYYY-MM-DD'),
            OpenApiParameter(name='time', type=OpenApiTypes.TIME, location=OpenApiParameter.QUERY, required=True, description='Точное время визита, HH:MM:SS'),
            OpenApiParameter(name='guests', type=OpenApiTypes.INT, location=OpenApiParameter.QUERY, required=True, description='Количество гостей (1–50)'),
            OpenApiParameter(name='zone_id', type=OpenApiTypes.INT, location=OpenApiParameter.QUERY, required=True, description='ID зала из /bookings/zones/'),
        ],
        responses={
            200: BookingTableSerializer(many=True),
            400: OpenApiResponse(description='Ошибка валидации параметров'),
            503: _error_503,
        },
        examples=[
            OpenApiExample(
                'Пример ответа',
                value=[
                    {'id': 4384, 'name': '202', 'capacity': 2},
                    {'id': 4391, 'name': '210', 'capacity': 2},
                ],
                response_only=True,
            ),
        ],
    )
    def get(self, request, *args, **kwargs):
        query = AvailableTablesQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        date = query.validated_data['date']
        time = query.validated_data['time']
        guests = query.validated_data['guests']
        zone_id = query.validated_data['zone_id']

        cache_key = _tables_cache_key_fmt.format(
            date=date.isoformat(), time=time.isoformat(), guests=guests, zone=zone_id,
        )
        tables = safe_cache_get(cache_key)
        if tables is None:
            try:
                tables = list_available_tables(date.isoformat(), time.strftime('%H:%M:%S'), guests, zone_id)
            except RemarkedAPIError:
                logger.warning(
                    "Available tables fetch failed: date=%s time=%s guests=%s zone_id=%s",
                    date, time, guests, zone_id, exc_info=True,
                )
                return Response({'detail': 'Проверка занятости временно недоступна'}, status=503)
            safe_cache_set(cache_key, tables, timeout=60)
        return Response(tables)

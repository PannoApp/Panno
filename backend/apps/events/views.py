from django.core.cache import cache
from django.shortcuts import get_object_or_404
from rest_framework import generics, viewsets, status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from utils.idempotency import IdempotencyMixin
from utils.pagination import StandardPagination
from utils.permissions import IsStaffOrAdmin
from .models import Event, News, EventReservation, EventPhotoReport
from .serializers import (
    EventSerializer, NewsSerializer, EventReservationSerializer,
    EventPhotoReportSerializer, StaffEventSerializer, StaffNewsSerializer,
    StaffPhotoReportCreateSerializer,
)

# Предстоящие/прошедшие события зависят от текущего времени — короткий TTL,
# чтобы список обновлялся автоматически когда событие «наступает».
_CACHE_EVENTS = 60
# Новости и архив меняются реже — можно кэшировать дольше.
_CACHE_NEWS   = 300


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
        description='Количество элементов на странице (по умолчанию 20, максимум 100)',
        required=False,
    ),
]

_error_401 = OpenApiResponse(description='Токен не передан или недействителен')


@extend_schema(
    tags=['Events'],
    summary='Список предстоящих мероприятий',
    description=(
        'Возвращает активные мероприятия с датой проведения **в будущем**, '
        'отсортированные по ближайшей дате.'
    ),
    parameters=_pagination_params,
    responses={200: EventSerializer(many=True)},
)
class UpcomingEventsListView(generics.ListAPIView):
    serializer_class = EventSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

    def get_queryset(self):
        return Event.objects.filter(is_active=True, date_time__gte=timezone.now()).order_by('date_time')

    def list(self, request, *args, **kwargs):
        # TTL=60 сек — список автоматически обновится когда событие «наступит».
        # При сохранении Event signals.py инкрементирует версию для мгновенной инвалидации.
        version   = cache.get_or_set('events_upcoming_cache_version', 1, timeout=None)
        cache_key = f'events_upcoming:{version}:{request.get_host()}:{request.query_params.urlencode()}'
        cached    = cache.get(cache_key)
        if cached is not None:
            return Response(cached)
        response = super().list(request, *args, **kwargs)
        cache.set(cache_key, response.data, timeout=_CACHE_EVENTS)
        return response


@extend_schema(
    tags=['Events'],
    summary='Архив прошедших мероприятий',
    description=(
        'Возвращает активные мероприятия с датой проведения **в прошлом**, '
        'отсортированные от самого свежего к старому.'
    ),
    parameters=_pagination_params,
    responses={200: EventSerializer(many=True)},
)
class ArchivedEventsListView(generics.ListAPIView):
    serializer_class = EventSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

    def get_queryset(self):
        return Event.objects.filter(is_active=True, date_time__lt=timezone.now()).order_by('-date_time')

    def list(self, request, *args, **kwargs):
        # Архив тоже зависит от текущего времени — аналогичный TTL=60 сек.
        version   = cache.get_or_set('events_archived_cache_version', 1, timeout=None)
        cache_key = f'events_archived:{version}:{request.get_host()}:{request.query_params.urlencode()}'
        cached    = cache.get(cache_key)
        if cached is not None:
            return Response(cached)
        response = super().list(request, *args, **kwargs)
        cache.set(cache_key, response.data, timeout=_CACHE_EVENTS)
        return response


@extend_schema(
    tags=['Events'],
    summary='Список новостей',
    description='Возвращает новости ресторана, отсортированные от самой свежей к старой.',
    parameters=_pagination_params,
    responses={200: NewsSerializer(many=True)},
)
class NewsListView(generics.ListAPIView):
    queryset = News.objects.all()
    serializer_class = NewsSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

    def list(self, request, *args, **kwargs):
        # Новости — статичный контент, кэшируем на 5 минут.
        version   = cache.get_or_set('events_news_cache_version', 1, timeout=None)
        cache_key = f'events_news:{version}:{request.get_host()}:{request.query_params.urlencode()}'
        cached    = cache.get(cache_key)
        if cached is not None:
            return Response(cached)
        response = super().list(request, *args, **kwargs)
        cache.set(cache_key, response.data, timeout=_CACHE_NEWS)
        return response


@extend_schema(
    tags=['Events'],
    summary='Записаться на мероприятие',
    description=(
        'Создаёт запись текущего авторизованного пользователя на выбранное мероприятие.\n\n'
        'Один пользователь не может записаться на одно мероприятие дважды — '
        'повторный запрос вернёт ошибку 400.'
    ),
    request=EventReservationSerializer,
    responses={
        201: EventReservationSerializer,
        400: OpenApiResponse(
            description='Ошибка валидации или повторная запись на то же мероприятие',
            examples=[
                OpenApiExample(
                    'Дубликат',
                    value={'non_field_errors': ['Вы уже записаны на это мероприятие.']},
                ),
                OpenApiExample(
                    'Ошибка валидации',
                    value={'event': ['Недопустимый первичный ключ — объект не существует.']},
                ),
            ],
        ),
        401: _error_401,
    },
    examples=[
        OpenApiExample(
            'Запись на мероприятие',
            value={'event': 3, 'guests_count': 2},
            request_only=True,
        )
    ],
)
class EventReservationCreateView(IdempotencyMixin, generics.CreateAPIView):
    serializer_class = EventReservationSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


@extend_schema(
    tags=['Events'],
    summary='Мои записи на мероприятия',
    description=(
        'Возвращает все записи на мероприятия текущего авторизованного пользователя '
        'с вложенными деталями каждого мероприятия (`event_details`).'
    ),
    parameters=_pagination_params,
    responses={
        200: EventReservationSerializer(many=True),
        401: _error_401,
    },
)
class UserEventReservationsListView(generics.ListAPIView):
    serializer_class = EventReservationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return EventReservation.objects.none()
        return EventReservation.objects.filter(user=self.request.user).select_related('event')


@extend_schema(
    tags=['Events'],
    summary='Фотоотчёт прошедшего мероприятия',
    description=(
        'Возвращает список фотографий фотоотчёта для указанного мероприятия. '
        'Доступно только для прошедших событий (date_time в прошлом). '
        'Если мероприятие ещё не прошло или фотоотчёт не загружен — возвращается пустой список.'
    ),
    parameters=[
        OpenApiParameter(
            name='event_id',
            type=OpenApiTypes.INT,
            location=OpenApiParameter.PATH,
            description='ID мероприятия',
        ),
    ],
    responses={200: EventPhotoReportSerializer(many=True)},
)
class EventPhotoReportListView(generics.ListAPIView):
    serializer_class = EventPhotoReportSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return EventPhotoReport.objects.filter(
            event_id=self.kwargs['event_id'],
            event__date_time__lt=timezone.now(),
        )


@extend_schema(tags=['Staff: Events'])
class StaffEventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.prefetch_related('reservations').order_by('-date_time')
    serializer_class = StaffEventSerializer
    permission_classes = [IsAuthenticated, IsStaffOrAdmin]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    pagination_class = None

    @action(
        detail=True,
        methods=['post'],
        url_path='photos',
        parser_classes=[MultiPartParser, FormParser],
    )
    def add_photo(self, request, pk=None):
        """Загружает фото в фотоотчёт прошедшего мероприятия."""
        event = self.get_object()
        serializer = StaffPhotoReportCreateSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(event=event)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(
        detail=True,
        methods=['delete'],
        url_path=r'photos/(?P<photo_pk>[^/.]+)',
        url_name='photo-delete',
    )
    def delete_photo(self, request, pk=None, photo_pk=None):
        """Удаляет фото из фотоотчёта мероприятия."""
        photo = get_object_or_404(EventPhotoReport, pk=photo_pk, event__pk=pk)
        photo.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=['Staff: Events'])
class StaffNewsViewSet(viewsets.ModelViewSet):
    queryset = News.objects.all().order_by('-created_at')
    serializer_class = StaffNewsSerializer
    permission_classes = [IsAuthenticated, IsStaffOrAdmin]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    pagination_class = None
    # destroy наследуется; django-cleanup удаляет файл при замене/удалении через on_commit

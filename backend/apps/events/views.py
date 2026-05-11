from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.utils import timezone
from utils.pagination import StandardPagination
from .models import Event, News, EventReservation
from .serializers import EventSerializer, NewsSerializer, EventReservationSerializer


class UpcomingEventsListView(generics.ListAPIView):
    serializer_class = EventSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

    def get_queryset(self):
        return Event.objects.filter(is_active=True, date_time__gte=timezone.now()).order_by('date_time')


class ArchivedEventsListView(generics.ListAPIView):
    serializer_class = EventSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

    def get_queryset(self):
        return Event.objects.filter(is_active=True, date_time__lt=timezone.now()).order_by('-date_time')


class NewsListView(generics.ListAPIView):
    queryset = News.objects.all()
    serializer_class = NewsSerializer
    permission_classes = [AllowAny]
    pagination_class = StandardPagination

class EventReservationCreateView(generics.CreateAPIView):
    """
    Создание записи на мероприятие.
    Доступно только авторизованным пользователям.
    """
    serializer_class = EventReservationSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # При сохранении автоматически подставляем пользователя из токена авторизации,
        # так как это поле мы сделали read_only в сериализаторе.
        serializer.save(user=self.request.user)

class UserEventReservationsListView(generics.ListAPIView):
    serializer_class = EventReservationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination

    def get_queryset(self):
        return EventReservation.objects.filter(user=self.request.user).select_related('event')
    
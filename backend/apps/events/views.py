from rest_framework import generics
from rest_framework.permissions import AllowAny
from django.utils import timezone
from .models import Event, News
from .serializers import EventSerializer, NewsSerializer

class UpcomingEventsListView(generics.ListAPIView):
    """
    Выдает список активных мероприятий, которые еще не начались или идут сейчас.
    Сортировка: от ближайших к более поздним.
    """
    serializer_class = EventSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        now = timezone.now()
        return Event.objects.filter(
            is_active=True, 
            date_time__gte=now # gte = Greater Than or Equal (больше или равно текущему времени)
        ).order_by('date_time')


class ArchivedEventsListView(generics.ListAPIView):
    """
    Выдает список прошедших мероприятий (архив).
    Сортировка: от самых недавних к старым.
    """
    serializer_class = EventSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        now = timezone.now()
        return Event.objects.filter(
            is_active=True, 
            date_time__lt=now # lt = Less Than (меньше текущего времени)
        ).order_by('-date_time')


class NewsListView(generics.ListAPIView):
    """
    Выдает список всех новостей.
    Сортировка задана в модели (самые свежие первыми).
    """
    queryset = News.objects.all()
    serializer_class = NewsSerializer
    permission_classes = [AllowAny]
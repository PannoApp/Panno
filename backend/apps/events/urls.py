from django.urls import path
from .views import UpcomingEventsListView, ArchivedEventsListView, NewsListView

app_name = 'events'

urlpatterns = [
    # Список будущих мероприятий
    path('upcoming/', UpcomingEventsListView.as_view(), name='event-upcoming'),
    # Архив прошедших мероприятий
    path('archived/', ArchivedEventsListView.as_view(), name='event-archived'),
    # Список новостей
    path('news/', NewsListView.as_view(), name='news-list'),
]
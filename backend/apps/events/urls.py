from django.urls import path
from .views import (
    UpcomingEventsListView,
    ArchivedEventsListView,
    NewsListView,
    EventReservationCreateView,
    UserEventReservationsListView,
    EventPhotoReportListView,
)

app_name = 'events'

urlpatterns = [
    # Список будущих мероприятий
    path('upcoming/', UpcomingEventsListView.as_view(), name='event-upcoming'),
    # Архив прошедших мероприятий
    path('archived/', ArchivedEventsListView.as_view(), name='event-archived'),
    # Список новостей
    path('news/', NewsListView.as_view(), name='news-list'),

    path('reservations/create/', EventReservationCreateView.as_view(), name='reservation-create'),
    path('reservations/my/', UserEventReservationsListView.as_view(), name='reservation-list'),

    # Фотоотчёт прошедшего мероприятия
    path('<int:event_id>/photo-report/', EventPhotoReportListView.as_view(), name='event-photo-report'),
]
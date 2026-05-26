from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UpcomingEventsListView,
    ArchivedEventsListView,
    NewsListView,
    EventReservationCreateView,
    UserEventReservationsListView,
    EventPhotoReportListView,
    StaffEventViewSet,
    StaffNewsViewSet,
)

app_name = 'events'

router = DefaultRouter()
router.register(r'staff/events', StaffEventViewSet, basename='staff-event')
router.register(r'staff/news', StaffNewsViewSet, basename='staff-news')

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

    # Staff CRUD
    path('', include(router.urls)),
]

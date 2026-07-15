from django.urls import path
from .views import (
    BookingAvailabilityView,
    BookingTablesView,
    BookingZonesView,
    TableBookingListCreateView,
    TelegramWebhookView,
)

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
    path('availability/', BookingAvailabilityView.as_view(), name='booking-availability'),
    path('zones/', BookingZonesView.as_view(), name='booking-zones'),
    path('tables/', BookingTablesView.as_view(), name='booking-tables'),
    path('telegram-webhook/', TelegramWebhookView.as_view(), name='telegram-webhook'),
]

from django.urls import path
from .views import (
    BookingAvailabilityView,
    BookingZonesView,
    TableBookingListCreateView,
    TelegramWebhookView,
)

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
    path('availability/', BookingAvailabilityView.as_view(), name='booking-availability'),
    path('zones/', BookingZonesView.as_view(), name='booking-zones'),
    path('telegram-webhook/', TelegramWebhookView.as_view(), name='telegram-webhook'),
]

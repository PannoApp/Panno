from django.urls import path
from .views import BookingAvailabilityView, TableBookingListCreateView, TelegramWebhookView

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
    path('availability/', BookingAvailabilityView.as_view(), name='booking-availability'),
    path('telegram-webhook/', TelegramWebhookView.as_view(), name='telegram-webhook'),
]

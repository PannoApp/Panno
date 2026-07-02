from django.urls import path
from .views import TableBookingListCreateView, TelegramWebhookView

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
    path('telegram-webhook/', TelegramWebhookView.as_view(), name='telegram-webhook'),
]

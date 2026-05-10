from django.urls import path
from .views import TableBookingListCreateView

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
]

from django.urls import path
from .views import TableBookingListCreateView, StaffBookingListView, StaffBookingUpdateView

app_name = 'bookings'

urlpatterns = [
    path('', TableBookingListCreateView.as_view(), name='booking-list-create'),
    path('staff/', StaffBookingListView.as_view(), name='staff-booking-list'),
    path('staff/<int:pk>/', StaffBookingUpdateView.as_view(), name='staff-booking-update'),
]

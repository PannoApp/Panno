from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import TableBooking
from .serializers import TableBookingSerializer


class TableBookingListCreateView(generics.ListCreateAPIView):
    serializer_class = TableBookingSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return TableBooking.objects.filter(user=self.request.user).order_by('-date', '-time')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

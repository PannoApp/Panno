from django.urls import path
from .views import RestaurantInfoView

app_name = 'core'

urlpatterns = [
    path('info/', RestaurantInfoView.as_view(), name='restaurant-info'),
]
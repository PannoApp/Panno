from django.urls import path
from .views import RestaurantInfoView, AppVersionView

app_name = 'core'

urlpatterns = [
    path('info/',        RestaurantInfoView.as_view(), name='restaurant-info'),
    path('app-version/', AppVersionView.as_view(),     name='app-version'),
]
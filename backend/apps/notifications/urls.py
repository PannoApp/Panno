from django.urls import path
from .views import RegisterDeviceView

app_name = 'notifications'

urlpatterns = [
    path('device/register/', RegisterDeviceView.as_view(), name='register_device'),
]
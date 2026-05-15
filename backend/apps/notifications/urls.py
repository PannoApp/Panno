from django.urls import path
from .views import RegisterDeviceView, BulkPushView

app_name = 'notifications'

urlpatterns = [
    path('device/register/', RegisterDeviceView.as_view(), name='register_device'),
    path('bulk-push/', BulkPushView.as_view(), name='bulk_push'),
]
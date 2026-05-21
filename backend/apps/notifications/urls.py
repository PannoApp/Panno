from django.urls import path
from .views import RegisterDeviceView, BulkPushView, SendPushViaBotView

app_name = 'notifications'

urlpatterns = [
    path('device/register/', RegisterDeviceView.as_view(), name='register_device'),
    path('bulk-push/', BulkPushView.as_view(), name='bulk_push'),
    path('send-push-via-bot/', SendPushViaBotView.as_view(), name='send_push_via_bot'),
]
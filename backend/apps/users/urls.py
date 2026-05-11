from django.urls import path
from .views import RequestSMSView, VerifySMSView, UserProfileView

app_name = 'users'

urlpatterns = [
    path('auth/request-sms/', RequestSMSView.as_view(), name='request-sms'),
    path('auth/verify-sms/', VerifySMSView.as_view(), name='verify-sms'),
    path('profile/', UserProfileView.as_view(), name='profile'),
]
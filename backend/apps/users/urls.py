from django.urls import path
from .views import RequestSMSView, VerifySMSView

urlpatterns = [
    path('auth/request-sms/', RequestSMSView.as_view(), name='request-sms'),
    path('auth/verify-sms/', VerifySMSView.as_view(), name='verify-sms'),
]
from django.urls import path
from .views import (
    DeleteAccountView,
    LogoutView,
    RequestSMSView,
    UserProfileView,
    VerifySMSView,
)

app_name = 'users'

urlpatterns = [
    path('auth/request-sms/', RequestSMSView.as_view(), name='request-sms'),
    path('auth/verify-sms/', VerifySMSView.as_view(), name='verify-sms'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('account/', DeleteAccountView.as_view(), name='delete-account'),
]
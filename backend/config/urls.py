from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    path('api/v1/', include([
        # Обновление access-токена по refresh — без повторного SMS-флоу
        path('users/auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
        path('users/',         include('apps.users.urls')),
        path('menu/',          include('apps.menu.urls')),
        path('events/',        include('apps.events.urls')),
        path('bookings/',      include('apps.bookings.urls')),
        path('core/',          include('apps.core.urls')),
        path('notifications/', include('apps.notifications.urls')),
    ])),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
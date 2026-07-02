from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from rest_framework_simplejwt.views import TokenRefreshView


def _cached_media(request, path):
    response = serve(request, path, document_root=settings.MEDIA_ROOT)
    response['Cache-Control'] = 'public, max-age=86400'
    return response

from django.contrib.auth import logout
from django.shortcuts import redirect

def custom_admin_logout(request):
    logout(request)
    return redirect('admin:index')

urlpatterns = [
    path('admin/logout/', custom_admin_logout, name='admin_logout_override'),
    path('admin/', admin.site.urls),
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
    # API-документация доступна только в режиме разработки.
    # В production эти маршруты отсутствуют, чтобы не раскрывать схему API.
    urlpatterns += [
        path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
        path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
        path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    ]
    media_prefix = settings.MEDIA_URL.lstrip('/')
    urlpatterns += [re_path(rf'^{media_prefix}(?P<path>.*)$', _cached_media)]
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/users/', include('users.urls')),
    path('api/menu/', include('menu.urls')),
    # Подключаем Афишу и Новости
    path('api/events/', include('events.urls')),
    # Подключаем Бронирование (если уже готов urls.py для bookings)
    path('api/bookings/', include('bookings.urls')),

]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
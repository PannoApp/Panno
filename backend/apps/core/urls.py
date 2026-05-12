from django.urls import path
from .views import RestaurantInfoView, AppVersionView, InteriorPhotoListView

app_name = 'core'

urlpatterns = [
    path('info/',      RestaurantInfoView.as_view(),    name='restaurant-info'),
    path('app-version/', AppVersionView.as_view(),      name='app-version'),
    # Галерея интерьера для вкладки «3D-тур / Интерьер»
    path('interior/',  InteriorPhotoListView.as_view(), name='interior-photos'),
]
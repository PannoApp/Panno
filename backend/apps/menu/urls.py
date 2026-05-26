from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DishListView, CategoryListView, TagListView, AllergenListView, VideoFeedView, StaffDishViewSet

app_name = 'menu'

router = DefaultRouter()
router.register(r'admin/dishes', StaffDishViewSet, basename='staff-dish')

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('tags/', TagListView.as_view(), name='tag-list'),
    path('allergens/', AllergenListView.as_view(), name='allergen-list'),
    path('dishes/', DishListView.as_view(), name='dish-list'),
    # Курсорная видеолента: только блюда с готовым обработанным видео
    path('feed/', VideoFeedView.as_view(), name='video-feed'),
    path('', include(router.urls)),
]
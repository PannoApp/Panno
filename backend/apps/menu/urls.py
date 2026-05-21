from django.urls import path
from .views import DishListView, CategoryListView, TagListView, VideoFeedView

app_name = 'menu'

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('tags/', TagListView.as_view(), name='tag-list'),
    path('dishes/', DishListView.as_view(), name='dish-list'),
    # Курсорная видеолента: только блюда с готовым обработанным видео
    path('feed/', VideoFeedView.as_view(), name='video-feed'),
]
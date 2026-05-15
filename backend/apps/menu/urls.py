from django.urls import path
from .views import DishListView, CategoryListView

app_name = 'menu'

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('dishes/', DishListView.as_view(), name='dish-list'),
]
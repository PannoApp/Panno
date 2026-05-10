from rest_framework import generics
from rest_framework.permissions import AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from .models import Dish, Category
from .serializers import DishSerializer, CategorySerializer
from .pagination import VideoFeedPagination
from .filters import DishFilter

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all().order_by('order')
    serializer_class = CategorySerializer
    permission_classes = [AllowAny]

class DishListView(generics.ListAPIView):
    queryset = (
        Dish.objects
        .filter(is_active=True)
        .select_related('category')
        .prefetch_related('tags', 'allergens')
        .order_by('category__order', 'id')
    )
    serializer_class = DishSerializer
    permission_classes = [AllowAny]
    pagination_class = VideoFeedPagination
    filter_backends = [DjangoFilterBackend]
    filterset_class = DishFilter
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.filters import SearchFilter
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, extend_schema_view, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from .models import Dish, Category
from .serializers import DishSerializer, CategorySerializer
from utils.pagination import VideoFeedPagination
from .filters import DishFilter


@extend_schema(
    tags=['Menu'],
    summary='Список категорий меню',
    description='Возвращает все категории блюд, отсортированные по полю `order`.',
    responses={200: CategorySerializer(many=True)},
)
class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all().order_by('order')
    serializer_class = CategorySerializer
    permission_classes = [AllowAny]


@extend_schema(
    tags=['Menu'],
    summary='Список блюд',
    description=(
        'Возвращает активные блюда меню с вложенными данными категории, тегов и аллергенов.\n\n'
        'Поддерживает фильтрацию по категории и тегу, а также пагинацию.\n\n'
        'По умолчанию возвращает **5 блюд** на страницу (формат видеоленты). '
        'Максимум — 20.'
    ),
    parameters=[
        OpenApiParameter(
            name='category_id',
            type=OpenApiTypes.INT,
            location=OpenApiParameter.QUERY,
            description='Фильтр по ID категории',
            required=False,
            examples=[],
        ),
        OpenApiParameter(
            name='tag_id',
            type=OpenApiTypes.INT,
            location=OpenApiParameter.QUERY,
            description='Фильтр по ID тега',
            required=False,
        ),
        OpenApiParameter(
            name='page',
            type=OpenApiTypes.INT,
            location=OpenApiParameter.QUERY,
            description='Номер страницы',
            required=False,
        ),
        OpenApiParameter(
            name='page_size',
            type=OpenApiTypes.INT,
            location=OpenApiParameter.QUERY,
            description='Количество блюд на странице (по умолчанию 5, максимум 20)',
            required=False,
        ),
        OpenApiParameter(
            name='search',
            type=OpenApiTypes.STR,
            location=OpenApiParameter.QUERY,
            description='Поиск по названию и описанию блюда (регистронезависимый)',
            required=False,
        ),
    ],
    responses={200: DishSerializer(many=True)},
)
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
    filter_backends = [DjangoFilterBackend, SearchFilter]
    filterset_class = DishFilter
    search_fields = ['name', 'description']

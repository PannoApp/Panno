from django.core.cache import cache
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.filters import SearchFilter
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, extend_schema_view, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from .models import Dish, Category
from .serializers import DishSerializer, CategorySerializer
from utils.pagination import VideoFeedPagination
from utils.cache import safe_cache_get, safe_cache_set
from .filters import DishFilter

# TTL кэша категорий (меняются редко) и страниц блюд (меняются чаще)
_CACHE_CATEGORIES = 3600
_CACHE_DISHES     = 300


@extend_schema(
    tags=['Menu'],
    summary='Список категорий меню',
    description='Возвращает все категории блюд, отсортированные по полю `order`.',
    responses={200: CategorySerializer(many=True)},
)
class CategoryListView(generics.ListAPIView):
    serializer_class = CategorySerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        # Категории меняются редко — кэшируем на 1 час.
        # Инвалидация через post_save/post_delete-сигнал в apps/menu/signals.py.
        # При недоступном Redis — fallback к прямому запросу в БД.
        categories = safe_cache_get('menu_categories')
        if categories is None:
            categories = list(Category.objects.all().order_by('order'))
            safe_cache_set('menu_categories', categories, timeout=_CACHE_CATEGORIES)
        return categories


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
            name='tag_ids',
            type=OpenApiTypes.STR,
            location=OpenApiParameter.QUERY,
            # Принимает список ID через запятую: ?tag_ids=1,2,3
            description='Фильтр по нескольким тегам (ID через запятую). Пример: ?tag_ids=1,2,3',
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
        # distinct() обязателен: при фильтрации по tag_ids блюдо с несколькими
        # совпавшими тегами без distinct вернётся в результатах несколько раз
        .distinct()
        .order_by('category__order', 'id')
    )
    serializer_class = DishSerializer
    permission_classes = [AllowAny]
    pagination_class = VideoFeedPagination
    filter_backends = [DjangoFilterBackend, SearchFilter]
    filterset_class = DishFilter
    search_fields = ['name', 'description']

    def list(self, request, *args, **kwargs):
        # Версионный кэш: при изменении любого блюда/категории/тега
        # signals.py инкрементирует 'menu_dishes_cache_version', что
        # автоматически делает все старые ключи недостижимыми.
        # При недоступном Redis — fallback к прямому запросу в БД.
        version = safe_cache_get('menu_dishes_cache_version', 1)
        cache_key = f'menu_dishes:{version}:{request.query_params.urlencode()}'
        cached = safe_cache_get(cache_key)
        if cached is not None:
            return Response(cached)
        response = super().list(request, *args, **kwargs)
        safe_cache_set(cache_key, response.data, timeout=_CACHE_DISHES)
        return response

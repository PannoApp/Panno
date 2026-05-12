import django_filters
from .models import Dish


class DishFilter(django_filters.FilterSet):
    # Фильтр по одной категории: ?category_id=1
    category_id = django_filters.NumberFilter(field_name='category__id')

    # Фильтр по нескольким тегам одновременно: ?tag_ids=1,2,3
    # BaseInFilter принимает значения через запятую и строит WHERE tags__id IN (1,2,3)
    # distinct() в queryset обязателен — иначе блюдо с двумя тегами из списка вернётся дважды
    tag_ids = django_filters.BaseInFilter(field_name='tags__id', lookup_expr='in')

    class Meta:
        model = Dish
        fields = ['category_id', 'tag_ids']
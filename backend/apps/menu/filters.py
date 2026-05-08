import django_filters
from .models import Dish

class DishFilter(django_filters.FilterSet):
    category_id = django_filters.NumberFilter(field_name='category__id')
    tag_id = django_filters.NumberFilter(field_name='tags__id')

    class Meta:
        model = Dish
        fields = ['category_id', 'tag_id']
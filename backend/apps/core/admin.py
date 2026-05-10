from django.contrib import admin
from .models import RestaurantInfo

@admin.register(RestaurantInfo)
class RestaurantInfoAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        # Запрещаем создавать больше одной записи
        return not RestaurantInfo.objects.exists()
    
    def has_delete_permission(self, request, onj=None):
        # Запрещаем удалять запись
        return False
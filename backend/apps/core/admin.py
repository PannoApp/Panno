from django.contrib import admin
from .models import RestaurantInfo, AppVersion

@admin.register(RestaurantInfo)
class RestaurantInfoAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        # Запрещаем создавать больше одной записи
        return not RestaurantInfo.objects.exists()
    
    def has_delete_permission(self, request, obj=None):
        # Запрещаем удалять запись
        return False


@admin.register(AppVersion)
class AppVersionAdmin(admin.ModelAdmin):
    list_display    = ('platform', 'min_version', 'latest_version', 'store_url', 'updated_at')
    readonly_fields = ('updated_at',)

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser
from django.contrib import admin
from .models import User


class AdminOnlyMixin:
    """Доступ только пользователям с role='admin' или is_superuser."""
    def has_module_perms(self, request, app_label):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_view_permission(self, request, obj=None):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_add_permission(self, request):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_change_permission(self, request, obj=None):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'


@admin.register(User)
class UserAdmin(AdminOnlyMixin, admin.ModelAdmin):
    list_display = ('phone', 'first_name', 'last_name', 'role', 'is_staff', 'is_active', 'date_joined')
    list_filter = ('role', 'is_staff', 'is_active')
    search_fields = ('phone', 'first_name', 'last_name')
    readonly_fields = ('date_joined',)
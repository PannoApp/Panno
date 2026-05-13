from django.contrib import admin
from utils.permissions import _has_role
from .models import User


class AdminOnlyMixin:
    """Доступ только пользователям с role='admin' или is_superuser."""
    def has_module_perms(self, request, app_label):
        return _has_role(request.user, 'admin')

    def has_view_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')

    def has_add_permission(self, request):
        return _has_role(request.user, 'admin')

    def has_change_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')

    def has_delete_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')


@admin.register(User)
class UserAdmin(AdminOnlyMixin, admin.ModelAdmin):
    list_display    = ('phone', 'first_name', 'last_name', 'role', 'is_staff', 'is_active', 'date_joined')
    list_filter     = ('role', 'is_staff', 'is_active')
    search_fields   = ('phone', 'first_name', 'last_name')
    readonly_fields = ('date_joined',)
    exclude         = ('groups', 'user_permissions')

    def save_model(self, request, obj, form, change):
        # Синхронизация is_staff выполняется автоматически в User.save().
        # Явный вызов здесь избыточен, но оставлен для читаемости —
        # редактор Admin видит намерение прямо в этом методе.
        super().save_model(request, obj, form, change)
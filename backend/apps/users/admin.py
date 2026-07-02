from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import UserChangeForm, UserCreationForm
from django import forms
from utils.permissions import _has_role
from .models import User


class AdminOnlyMixin:
    """Доступ только пользователям с role='admin' или is_superuser."""
    def has_module_permission(self, request):
        return _has_role(request.user, 'admin')

    def has_view_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')

    def has_add_permission(self, request):
        return _has_role(request.user, 'admin')

    def has_change_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')

    def has_delete_permission(self, request, obj=None):
        return _has_role(request.user, 'admin')


class CustomUserChangeForm(UserChangeForm):
    class Meta(UserChangeForm.Meta):
        model = User


class CustomUserCreationForm(UserCreationForm):
    class Meta(UserCreationForm.Meta):
        model = User
        fields = ('phone', 'role', 'is_active', 'is_staff', 'is_superuser')


@admin.register(User)
class UserAdmin(AdminOnlyMixin, BaseUserAdmin):
    form = CustomUserChangeForm
    add_form = CustomUserCreationForm

    list_display    = ('phone', 'first_name', 'last_name', 'role', 'telegram_id', 'is_staff', 'is_active', 'date_joined')
    list_filter     = ('role', 'is_staff', 'is_active')
    search_fields   = ('phone', 'first_name', 'last_name', 'telegram_id')
    ordering        = ('phone',)

    fieldsets = (
        (None, {'fields': ('phone', 'password')}),
        ('Персональная информация', {'fields': ('first_name', 'last_name', 'role', 'telegram_id')}),
        ('Права доступа', {'fields': ('is_active', 'is_staff', 'is_superuser')}),
        ('Настройки уведомлений', {'fields': ('notifications_enabled', 'notify_events', 'notify_promotions', 'notify_closed_events')}),
        ('Важные даты', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone', 'role', 'is_active', 'is_staff', 'is_superuser'),
        }),
    )

    readonly_fields = ('date_joined', 'last_login')
    filter_horizontal = ()
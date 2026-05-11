from django.contrib import admin
from .models import UserDevice


def _is_content_or_admin(user):
    return user.is_superuser or getattr(user, 'role', '') in ('admin', 'content_manager')


@admin.register(UserDevice)
class UserDeviceAdmin(admin.ModelAdmin):

    def has_view_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_add_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_delete_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    list_display = ('user', 'fcm_token_short', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__phone', 'fcm_token')
    readonly_fields = ('created_at',)

    def fcm_token_short(self, obj):
        return obj.fcm_token[:40] + '...' if len(obj.fcm_token) > 40 else obj.fcm_token
    fcm_token_short.short_description = 'FCM Токен'

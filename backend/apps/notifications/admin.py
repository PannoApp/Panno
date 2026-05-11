from django.contrib import admin
from .models import UserDevice


@admin.register(UserDevice)
class UserDeviceAdmin(admin.ModelAdmin):
    list_display = ('user', 'fcm_token_short', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__phone', 'fcm_token')
    readonly_fields = ('created_at',)

    def fcm_token_short(self, obj):
        return obj.fcm_token[:40] + '...' if len(obj.fcm_token) > 40 else obj.fcm_token
    fcm_token_short.short_description = 'FCM Токен'

from django.contrib import admin
from .models import User

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('phone', 'first_name', 'last_name', 'is_staff', 'is_active', 'notifications_enabled', 'date_joined')
    list_filter = ('is_staff', 'is_active', 'notifications_enabled')
    search_fields = ('phone', 'first_name', 'last_name')
    readonly_fields = ('date_joined',)
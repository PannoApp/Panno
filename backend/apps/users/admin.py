from django.contrib import admin
from .models import User

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('phone', 'first_name', 'is_staff', 'is_active')
    search_fields = ('phone', 'first_name')
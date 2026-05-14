from django.contrib.admin import ModelAdmin
from django.contrib import admin
from django.utils.safestring import mark_safe
from utils.permissions import _has_role
from .models import Event, News, EventReservation


def _is_content_or_admin(user):
    return _has_role(user, 'admin', 'content_manager')


def _is_hall_or_admin(user):
    return _has_role(user, 'admin', 'hall_manager')

@admin.register(EventReservation)
class EventReservationAdmin(ModelAdmin):
    list_display = ('event', 'guest_name', 'guest_phone', 'guests_count', 'created_at')
    list_filter = ('event',)
    search_fields = ('user__phone', 'user__first_name', 'user__last_name', 'event__title')
    readonly_fields = ('created_at',)

    @admin.display(description='Имя гостя')
    def guest_name(self, obj):
        if not obj.user:
            return '—'
        full = f"{obj.user.first_name} {obj.user.last_name}".strip()
        return full or obj.user.phone

    @admin.display(description='Телефон')
    def guest_phone(self, obj):
        return obj.user.phone if obj.user else '—'

    def has_module_permission(self, request):
        return _is_hall_or_admin(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_hall_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_hall_or_admin(request.user)

    def has_add_permission(self, request):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'


@admin.register(Event)
class EventAdmin(ModelAdmin):
    """
    Настройка админки для мероприятий (Афиши).
    """
    list_display = ('title', 'date_time', 'format', 'price', 'is_active', 'image_preview')
    
    # Фильтры: по активности и дате
    list_filter = ('is_active', 'date_time')
    
    # Поиск по заголовку и описанию
    search_fields = ('title', 'description')
    
    # Возможность быстро включать/выключать мероприятие из списка
    list_editable = ('is_active',)
    
    readonly_fields = ('image_preview_big',)

    def has_module_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_add_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_delete_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def image_preview(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="50" height="50" style="object-fit: cover; border-radius: 4px;" />')
        return "Нет фото"
    image_preview.short_description = "Миниатюра"

    def image_preview_big(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="300" style="border-radius: 8px;" />')
        return "Фото не загружено"
    image_preview_big.short_description = "Предпросмотр обложки"


@admin.register(News)
class NewsAdmin(ModelAdmin):
    """
    Настройка админки для новостей.
    """
    # В списке новостей показываем заголовок, дату публикации и картинку
    list_display = ('title', 'created_at', 'image_preview')
    
    # Поиск по тексту и заголовку
    search_fields = ('title', 'content')
    
    # Сортировка (дублируем ту, что в модели, для надежности)
    ordering = ('-created_at',)
    
    readonly_fields = ('image_preview_big',)

    def has_module_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_add_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_delete_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def image_preview(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="50" height="50" style="object-fit: cover; border-radius: 4px;" />')
        return "Без фото"
    image_preview.short_description = "Миниатюра"

    def image_preview_big(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="300" style="border-radius: 8px;" />')
        return "Фото не загружено"
    image_preview_big.short_description = "Предпросмотр изображения"
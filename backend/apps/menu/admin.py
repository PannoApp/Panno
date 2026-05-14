from django.contrib import admin
from django.utils.safestring import mark_safe
from utils.permissions import _has_role
from .models import Category, Tag, Allergen, Dish


def _is_content_or_admin(user):
    return _has_role(user, 'admin', 'content_manager')


class ContentManagerMixin:
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


@admin.register(Category)
class CategoryAdmin(ContentManagerMixin, admin.ModelAdmin):
    list_display = ('name', 'order')
    list_editable = ('order',)  # Позволяет менять порядок прямо в списке
    search_fields = ('name',)

@admin.register(Tag)
class TagAdmin(ContentManagerMixin, admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Allergen)
class AllergenAdmin(ContentManagerMixin, admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Dish)
class DishAdmin(ContentManagerMixin, admin.ModelAdmin):
    # Колонки в общем списке
    list_display = ('name', 'category', 'price', 'is_active', 'image_preview_list')
    # Фильтры в правой панели
    list_filter = ('category', 'is_active', 'tags', 'allergens')
    # Поиск по имени и описанию
    search_fields = ('name', 'description')
    # Поля, которые можно редактировать прямо из списка
    list_editable = ('is_active', 'price')
    # Поля только для чтения (для отображения медиа)
    readonly_fields = ('image_preview_detail', 'video_preview_detail')
    # Удобный интерфейс выбора для полей ManyToMany
    filter_horizontal = ('tags', 'allergens')

    # Группировка полей внутри карточки блюда
    fieldsets = (
        ('Основная информация', {
            'fields': ('name', 'description', 'price', 'category', 'is_active')
        }),
        ('Характеристики', {
            'fields': ('tags', 'allergens')
        }),
        ('Медиа', {
            'fields': ('image', 'image_preview_detail', 'video', 'video_preview_detail')
        }),
    )

    # Метод для миниатюры в общем списке блюд
    def image_preview_list(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="50" height="50" style="object-fit: cover; border-radius: 5px;" />')
        return "Нет фото"
    image_preview_list.short_description = 'Фото'

    # Метод для большой картинки внутри карточки блюда
    def image_preview_detail(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="300" style="border-radius: 10px;" />')
        return "Нет фото"
    image_preview_detail.short_description = 'Предпросмотр фото'

    # Метод для видеоплеера внутри карточки блюда
    def video_preview_detail(self, obj):
        if obj.video:
            return mark_safe(f'<video width="300" controls><source src="{obj.video.url}" type="video/mp4">Ваш браузер не поддерживает видео.</video>')
        return "Нет видео"
    video_preview_detail.short_description = 'Предпросмотр видео'
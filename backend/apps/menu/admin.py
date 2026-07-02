from django.contrib.admin import ModelAdmin
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
class CategoryAdmin(ContentManagerMixin, ModelAdmin):
    list_display = ('name', 'order')
    list_editable = ('order',)  # Позволяет менять порядок прямо в списке
    search_fields = ('name',)

@admin.register(Tag)
class TagAdmin(ContentManagerMixin, ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Allergen)
class AllergenAdmin(ContentManagerMixin, ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Dish)
class DishAdmin(ContentManagerMixin, ModelAdmin):
    class Media:
        js = ('menu/js/admin_media_helper.js',)
        css = {
            'all': ('menu/css/admin_media_helper.css',)
        }

    # Колонки в общем списке; video_status позволяет сразу видеть этап обработки видео
    list_display = ('name', 'category', 'price', 'is_active', 'video_status', 'image_preview_list')
    # Фильтры в правой панели
    list_filter = ('category', 'is_active', 'tags', 'allergens')
    # Поиск по имени и описанию
    search_fields = ('name', 'description')
    # Поля, которые можно редактировать прямо из списка
    list_editable = ('is_active', 'price')
    # Поля только для чтения: медиа-превью и статус обработки видео (меняется Celery, не вручную)
    readonly_fields = ('image_preview_detail', 'video_preview_detail', 'video_status')
    # Удобный интерфейс выбора для полей ManyToMany
    filter_horizontal = ('tags', 'allergens')

    # Группировка полей внутри карточки блюда
    fieldsets = (
        ('Основная информация', {
            'fields': ('name', 'description', 'price', 'category', 'weight', 'is_active')
        }),
        ('Характеристики', {
            'fields': ('tags', 'allergens')
        }),
        ('История блюда', {
            'fields': ('story',)
        }),
        ('Медиа', {
            # video_status — только для чтения; отображает текущий этап транскодирования Celery
            'fields': ('image', 'image_preview_detail', 'video', 'video_preview_detail', 'video_status')
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
            return mark_safe(f'<img src="{obj.image.url}" width="300" style="border-radius: 10px; display: block;" />')
        return "Нет фото"
    image_preview_detail.short_description = 'Предпросмотр фото'

    # Метод для видеоплеера внутри карточки блюда с сеткой безопасной зоны
    def video_preview_detail(self, obj):
        if obj.video:
            return mark_safe(f'''
                <div class="video-preview-wrapper" style="position: relative; width: 300px; display: inline-block; border-radius: 10px; overflow: hidden; background: #000;">
                    <video id="video-preview-element" width="300" controls style="display: block;">
                        <source src="{obj.video.url}" type="video/mp4">
                        Ваш браузер не поддерживает видео.
                    </video>
                    <div class="video-safe-zone-overlay" style="position: absolute; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; border: 2px dashed rgba(255, 0, 0, 0.4); box-sizing: border-box;">
                        <div class="video-overlay-text top-scrim" style="position: absolute; top: 0; left: 0; right: 0; height: 15%; background: rgba(255, 0, 0, 0.15); color: #fff; font-size: 10px; padding: 2px; text-align: center; border-bottom: 1px dotted red; font-family: sans-serif;">Зона статус-бара / звука (15%)</div>
                        <div class="video-overlay-text side-safe-left" style="position: absolute; top: 15%; left: 0; width: 10%; bottom: 35%; background: rgba(255, 165, 0, 0.15); border-right: 1px dotted orange;"></div>
                        <div class="video-overlay-text side-safe-right" style="position: absolute; top: 15%; right: 0; width: 10%; bottom: 35%; background: rgba(255, 165, 0, 0.15); border-left: 1px dotted orange;"></div>
                        <div class="video-overlay-text main-safe-zone" style="position: absolute; top: 15%; left: 10%; right: 10%; bottom: 35%; display: flex; align-items: center; justify-content: center; color: #00ff00; font-size: 12px; font-weight: bold; text-shadow: 1px 1px 2px #000; font-family: sans-serif;">БЕЗОПАСНАЯ ЗОНА (Центр)</div>
                        <div class="video-overlay-text bottom-scrim" style="position: absolute; bottom: 0; left: 0; right: 0; height: 35%; background: rgba(255, 0, 0, 0.15); color: #fff; font-size: 10px; padding: 2px; text-align: center; border-top: 1px dotted red; display: flex; align-items: center; justify-content: center; font-family: sans-serif;">Зона описания / цены (35%)</div>
                    </div>
                </div>
                <div style="margin-top: 5px;">
                    <label><input type="checkbox" id="toggle-video-overlay" checked style="vertical-align: middle; margin-right: 5px;">Показывать сетку безопасной зоны приложения</label>
                </div>
                <script>
                    document.getElementById('toggle-video-overlay')?.addEventListener('change', function(e) {{
                        const overlay = this.closest('div').previousElementSibling.querySelector('.video-safe-zone-overlay');
                        if (overlay) overlay.style.display = this.checked ? 'block' : 'none';
                    }});
                </script>
            ''')
        return "Нет видео"
    video_preview_detail.short_description = 'Предпросмотр видео'
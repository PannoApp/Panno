from django.contrib import admin
from django.utils.safestring import mark_safe
from .models import Event, News

@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    """
    Настройка админки для мероприятий (Афиши).
    """
    # Что видим в списке: название, дата проведения, статус и миниатюра
    list_display = ('title', 'date_time', 'is_active', 'image_preview')
    
    # Фильтры: по активности и дате
    list_filter = ('is_active', 'date_time')
    
    # Поиск по заголовку и описанию
    search_fields = ('title', 'description')
    
    # Возможность быстро включать/выключать мероприятие из списка
    list_editable = ('is_active',)
    
    # Поля только для чтения (для предпросмотра картинки)
    readonly_fields = ('image_preview_big',)

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
class NewsAdmin(admin.ModelAdmin):
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
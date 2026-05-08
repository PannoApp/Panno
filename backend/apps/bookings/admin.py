from django.contrib import admin
from .models import TableBooking

@admin.register(TableBooking)
class TableBookingAdmin(admin.ModelAdmin):
    """
    Настройка отображения бронирований в панели администратора.
    """

    # Колонки, которые будут видны в общем списке
    list_display = (
        'guest_name', 
        'date', 
        'time', 
        'guests_count', 
        'status', 
        'user', 
        'created_at'
    )
    
    # Фильтры в правой панели (по статусу и дате визита)
    list_filter = ('status', 'date', 'created_at')
    
    # Поля для поиска (по имени гостя, комментарию и данным связанного пользователя)
    search_fields = ('guest_name', 'comment', 'user__phone', 'user__first_name')
    
    # Позволяет быстро менять статус прямо в списке, не заходя в карточку
    list_editable = ('status',)
    
    # Поля, которые нельзя редактировать (дата создания устанавливается автоматически)
    readonly_fields = ('created_at',)
    
    # Группировка полей в форме редактирования для удобства менеджера
    fieldsets = (
        ('Основная информация', {
            'fields': ('user', 'guest_name', 'guests_count', 'comment')
        }),
        ('Детали визита', {
            'fields': ('date', 'time', 'status')
        }),
        ('Системные данные', {
            'fields': ('created_at',),
        }),
    )
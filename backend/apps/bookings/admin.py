from django.contrib.admin import ModelAdmin
from django.contrib import admin
from utils.permissions import _has_role
from .models import TableBooking


def _is_hall_manager(user):
    return _has_role(user, 'admin', 'hall_manager')


@admin.register(TableBooking)
class TableBookingAdmin(ModelAdmin):

    def has_module_permission(self, request):
        return _is_hall_manager(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_hall_manager(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_hall_manager(request.user)

    def has_add_permission(self, request):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser or getattr(request.user, 'role', '') == 'admin'

    """
    Настройка отображения бронирований в панели администратора.
    """

    # Колонки, которые будут видны в общем списке
    list_display = (
        'guest_name',
        'phone',
        'date',
        'time',
        'guests_count',
        'zone',
        'status',
        'user',
        'remarked_reserve_id',
        'created_at',
    )
    
    # Фильтры в правой панели (по статусу и дате визита)
    list_filter = ('status', 'zone', 'date', 'created_at')
    
    # Поля для поиска (по имени гостя, комментарию и данным связанного пользователя)
    search_fields = ('guest_name', 'phone', 'comment', 'user__phone', 'user__first_name')
    
    # Позволяет быстро менять статус прямо в списке, не заходя в карточку
    list_editable = ('status',)
    
    # Поля, которые нельзя редактировать (дата создания устанавливается автоматически)
    readonly_fields = ('created_at',)
    
    # Группировка полей в форме редактирования для удобства менеджера
    fieldsets = (
        ('Основная информация', {
            'fields': ('user', 'guest_name', 'phone', 'guests_count', 'comment')
        }),
        ('Детали визита', {
            'fields': ('date', 'time', 'zone', 'status')
        }),
        ('Системные данные', {
            'fields': ('remarked_reserve_id', 'created_at'),
        }),
    )
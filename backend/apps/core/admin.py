from django.contrib.admin import ModelAdmin, TabularInline
from django.contrib import admin
from django.utils.safestring import mark_safe
from utils.permissions import _has_role
from .models import RestaurantInfo, AppVersion, InteriorPhoto, HeroSlide, VisitRule


def _is_content_or_admin(user):
    """Контент-менеджер или администратор."""
    return _has_role(user, 'admin', 'content_manager')


def _is_admin_only(user):
    """Только администратор (или суперпользователь)."""
    return _has_role(user, 'admin')


class VisitRuleInline(TabularInline):
    model = VisitRule
    extra = 1
    fields = ('title', 'body', 'order')
    ordering = ('order',)
    verbose_name = "Правило"
    verbose_name_plural = "Правила посещения"


class HeroSlideInline(TabularInline):
    model = HeroSlide
    extra = 1
    fields = ('image', 'order', 'image_preview')
    readonly_fields = ('image_preview',)

    def image_preview(self, obj):
        if obj and obj.image:
            return mark_safe(f'<img src="{obj.image.url}" height="60" style="border-radius:4px;" />')
        return "—"
    image_preview.short_description = "Превью"


@admin.register(RestaurantInfo)
class RestaurantInfoAdmin(ModelAdmin):
    """
    Синглтон-настройки ресторана.
    Добавлять/удалять нельзя — только редактировать.
    Доступен: admin и content_manager.
    """

    # Группировка полей по смысловым блокам — удобнее для менеджера
    fieldsets = (
        ('Контакты и адрес', {
            'fields': ('address', 'phone', 'whatsapp', 'telegram', 'instagram', 'feedback_url'),
        }),
        ('Часы работы', {
            'fields': ('working_hours', 'working_hours_note'),
            'description': (
                'Формат часов: «Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00».'
                ' В поле «Временное изменение» укажите разовое уведомление '
                '(например: «Закрыто 1 января»). Приложение покажет его гостям поверх основного расписания.'
            ),
        }),
        ('Маршруты', {
            'fields': ('twogis_link', 'google_maps_link', 'yandex_maps_link', 'tour_link'),
        }),
        ('Контент главной', {
            'fields': ('concept_description',),
        }),
        ('Бронирование', {
            'fields': ('booking_deposit_required', 'booking_deposit_note'),
        }),
        ('Юридические тексты', {
            'fields': ('privacy_policy', 'terms_of_service'),
            'classes': ('collapse',),
        }),
    )

    inlines = [VisitRuleInline, HeroSlideInline]

    # Доступ по ролям
    def has_module_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_add_permission(self, request):
        # Синглтон — добавление запрещено если запись уже существует
        return _is_admin_only(request.user) and not RestaurantInfo.objects.exists()

    def has_delete_permission(self, request, obj=None):
        # Удаление синглтона запрещено всегда (даже для суперпользователя — логика в модели)
        return False


@admin.register(InteriorPhoto)
class InteriorPhotoAdmin(ModelAdmin):
    """Фото интерьера — управляет контент-менеджер."""

    list_display   = ('zone', 'caption', 'order', 'image_preview')
    list_filter    = ('zone',)
    list_editable  = ('order',)
    search_fields  = ('caption',)
    readonly_fields = ('image_preview_detail',)

    fieldsets = (
        (None, {
            'fields': ('zone', 'caption', 'order', 'image', 'image_preview_detail'),
        }),
    )

    def image_preview(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="60" height="60" style="object-fit:cover;border-radius:4px;" />')
        return '—'
    image_preview.short_description = 'Фото'

    def image_preview_detail(self, obj):
        if obj.image:
            return mark_safe(f'<img src="{obj.image.url}" width="300" style="border-radius:8px;" />')
        return 'Фото не загружено'
    image_preview_detail.short_description = 'Предпросмотр'

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


@admin.register(AppVersion)
class AppVersionAdmin(ModelAdmin):
    """
    Версии приложения — только для роли admin.
    Управляет обязательным/рекомендуемым обновлением в Flutter.
    """

    list_display    = ('platform', 'min_version', 'latest_version', 'store_url', 'updated_at')
    readonly_fields = ('updated_at',)

    # Доступ — только администратор (изменение версий влияет на поведение всех клиентов)
    def has_module_permission(self, request):
        return _is_admin_only(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_admin_only(request.user)

    def has_add_permission(self, request):
        return _is_admin_only(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_admin_only(request.user)

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser

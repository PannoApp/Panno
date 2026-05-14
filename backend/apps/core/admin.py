from django.contrib import admin
from django.utils.safestring import mark_safe
from utils.permissions import _has_role
from .models import RestaurantInfo, AppVersion, InteriorPhoto


def _is_content_or_admin(user):
    """Контент-менеджер или администратор."""
    return _has_role(user, 'admin', 'content_manager')


def _is_admin_only(user):
    """Только администратор (или суперпользователь)."""
    return _has_role(user, 'admin')


@admin.register(RestaurantInfo)
class RestaurantInfoAdmin(admin.ModelAdmin):
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
            'fields': ('concept_description', 'hero_image', 'hero_video_url'),
        }),
        ('Бронирование', {
            'fields': ('booking_deposit_required', 'booking_deposit_note'),
        }),
        ('Юридические тексты', {
            'fields': ('visit_rules', 'privacy_policy', 'terms_of_service'),
            'classes': ('collapse',),  # Скрыто по умолчанию — редко редактируется
        }),
    )

    # Превью изображения героя прямо в форме
    readonly_fields = ('hero_image_preview',)

    def get_fieldsets(self, request, obj=None):
        """Добавляем превью героя в соответствующую секцию."""
        fieldsets = list(super().get_fieldsets(request, obj))
        for i, (name, opts) in enumerate(fieldsets):
            if name == 'Контент главной':
                fields = list(opts['fields'])
                if 'hero_image_preview' not in fields:
                    fields.insert(fields.index('hero_image') + 1, 'hero_image_preview')
                fieldsets[i] = (name, {**opts, 'fields': tuple(fields)})
        return fieldsets

    def hero_image_preview(self, obj):
        if obj and obj.hero_image:
            return mark_safe(f'<img src="{obj.hero_image.url}" width="400" style="border-radius:8px;" />')
        return "Изображение не загружено"
    hero_image_preview.short_description = "Предпросмотр заглавного изображения"

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
class InteriorPhotoAdmin(admin.ModelAdmin):
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
class AppVersionAdmin(admin.ModelAdmin):
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

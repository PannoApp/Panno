from django.contrib.admin import ModelAdmin
from django.contrib import admin
from .models import UserDevice, PushCampaign

try:
    from rest_framework_simplejwt.token_blacklist.admin import (
        BlacklistedTokenAdmin,
        OutstandingTokenAdmin,
    )
    from rest_framework_simplejwt.token_blacklist.models import (
        BlacklistedToken,
        OutstandingToken,
    )
    admin.site.unregister(BlacklistedToken)
    admin.site.unregister(OutstandingToken)
except Exception:
    pass


def _is_content_or_admin(user):
    return user.is_superuser or getattr(user, 'role', '') in ('admin', 'content_manager')


@admin.register(UserDevice)
class UserDeviceAdmin(ModelAdmin):

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

    list_display = ('user', 'created_at', 'updated_at')
    list_filter = ('created_at',)
    search_fields = ('user__phone',)
    readonly_fields = ('user', 'created_at', 'updated_at')
    fields = ('user', 'created_at', 'updated_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


from django import forms

class PushCampaignForm(forms.ModelForm):
    SEGMENT_CHOICES = [
        ('all', 'Всем (у кого есть приложение)'),
        ('last_visit_days', 'Активные (бронировали за последние 30 дней)'),
    ]
    CATEGORY_CHOICES = [
        ('', 'Сервисное (без ограничений)'),
        ('events', 'Мероприятия — уважает настройки + лимит'),
        ('promotions', 'Акции — уважает настройки + лимит'),
        ('closed_events', 'Закрытые мероприятия — уважает настройки + лимит'),
    ]
    segment = forms.ChoiceField(
        choices=SEGMENT_CHOICES,
        initial='all',
        label="Кому отправить",
        help_text="Выберите аудиторию для рассылки"
    )
    category = forms.ChoiceField(
        choices=CATEGORY_CHOICES,
        required=False,
        initial='',
        label="Категория",
        help_text="Сервисное — отправляется сразу всем без ограничений. Остальные — проверяют настройки пользователя и время (9:00–21:00).",
    )

    class Meta:
        model = PushCampaign
        fields = '__all__'


@admin.register(PushCampaign)
class PushCampaignAdmin(ModelAdmin):
    form = PushCampaignForm
    list_display = (
        'created_at', 'title', 'category', 'segment',
        'total_users', 'delivered_count', 'failed_count',
    )
    list_filter = ('category', 'segment', 'created_at')
    search_fields = ('title',)
    
    def get_readonly_fields(self, request, obj=None):
        if obj:
            return (
                'created_at', 'title', 'body', 'category', 'segment',
                'total_users', 'delivered_count', 'failed_count',
            )
        return ('created_at', 'total_users', 'delivered_count', 'failed_count')

    def save_model(self, request, obj, form, change):
        if not change:
            # Логика сбора аудитории при создании рассылки
            segment = obj.segment
            user_ids = []
            
            if segment == 'all':
                user_ids = list(UserDevice.objects.values_list('user_id', flat=True).distinct())
            elif segment == 'last_visit_days':
                from django.utils import timezone
                from datetime import timedelta
                from apps.bookings.models import TableBooking
                since = timezone.now() - timedelta(days=30)
                raw_ids = list(TableBooking.objects.filter(
                    status='completed', updated_at__gte=since, user__isnull=False
                ).values_list('user_id', flat=True).distinct())
                user_ids = list(UserDevice.objects.filter(user_id__in=raw_ids).values_list('user_id', flat=True).distinct())
            
            obj.total_users = len(user_ids)
            super().save_model(request, obj, form, change)
            
            # Ставим задачу в очередь
            from .tasks import send_bulk_push_notification
            send_bulk_push_notification.delay(
                user_ids=user_ids,
                title=obj.title,
                body=obj.body,
                data={},
                category=obj.category,
                campaign_id=obj.pk
            )
        else:
            super().save_model(request, obj, form, change)

    def has_module_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_view_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_add_permission(self, request):
        return _is_content_or_admin(request.user)

    def has_change_permission(self, request, obj=None):
        return _is_content_or_admin(request.user)

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser

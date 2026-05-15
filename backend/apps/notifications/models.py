from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

class UserDevice(models.Model):
    user = models.ForeignKey(
        User, 
        related_name='devices', 
        on_delete=models.CASCADE, 
        verbose_name="Пользователь"
    )
    fcm_token = models.CharField(
        max_length=4096,
        unique=True,
        verbose_name="FCM Токен"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Дата добавления"
    )

    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="Дата обновления"
    )

    class Meta:
        app_label = 'notifications'
        verbose_name = "Устройство пользователя"
        verbose_name_plural = "Устройства пользователей"

    def __str__(self):
        return f"Устройство пользователя ID {self.user.id}"


class PushCampaign(models.Model):
    created_at      = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    title           = models.CharField(max_length=255, verbose_name="Заголовок")
    body            = models.TextField(verbose_name="Текст")
    category        = models.CharField(max_length=50, blank=True, verbose_name="Категория")
    segment         = models.CharField(max_length=50, blank=True, verbose_name="Сегмент")
    total_users     = models.PositiveIntegerField(default=0, verbose_name="Всего получателей")
    delivered_count = models.PositiveIntegerField(default=0, verbose_name="Доставлено")
    failed_count    = models.PositiveIntegerField(default=0, verbose_name="Ошибок")

    class Meta:
        app_label = 'notifications'
        verbose_name = "Push-кампания"
        verbose_name_plural = "Push-кампании"
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.created_at:%Y-%m-%d}] {self.title} ({self.segment})"
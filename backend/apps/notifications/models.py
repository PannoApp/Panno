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
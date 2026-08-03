from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

# Метка в data-поле пушей, которые реально отправлены нашим send_push_notification —
# позволяет отличить их в PushReceipt от пушей, пришедших в обход backend'а
# (Remarked напрямую через Firebase). Значение — строка (FCM требует строки в data).
OWN_CHANNEL_DATA_KEY = '_source'
OWN_CHANNEL_DATA_VALUE = 'panno_backend'


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


class PushReceipt(models.Model):
    """
    Факт получения push на устройстве — со стороны клиента, а не отправки.
    Нужен в первую очередь для пушей Remarked, отправленных напрямую через
    Firebase в обход этого backend'а (см. docs/notifications.md) — единственный
    источник видимости, что и когда реально пришло на телефон.

    Не привязана к UserDevice (FK, CASCADE) намеренно: устройство может быть
    удалено (невалидный токен, см. send_push_notification) или перепривязано
    к другому пользователю позже, а исторический лог о том, что конкретный
    токен когда-то получил конкретный пуш, должен пережить это. Пользователь
    резолвится один раз на момент записи (SET_NULL, если позже удалён).
    """
    user = models.ForeignKey(
        User,
        related_name='push_receipts',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        verbose_name="Пользователь",
    )
    fcm_token = models.CharField(
        max_length=4096,
        db_index=True,
        verbose_name="FCM токен устройства",
    )
    title = models.CharField(max_length=255, blank=True, verbose_name="Заголовок")
    body = models.TextField(blank=True, verbose_name="Текст")
    data = models.JSONField(default=dict, blank=True, verbose_name="Данные (data)")
    # 'foreground' — получено, пока приложение было открыто (onMessage);
    # 'opened_app' — приложение открыто тапом по уведомлению (фон/закрыто);
    # 'background' — получено в фоне без тапа (onBackgroundMessage).
    context = models.CharField(max_length=20, verbose_name="Контекст получения")
    is_own_channel = models.BooleanField(
        default=False,
        verbose_name="Отправлено нашим backend'ом",
        help_text="True, если в data есть наша внутренняя метка _source — "
                   "иначе пуш пришёл в обход backend'а (например, от Remarked).",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Записано")

    class Meta:
        app_label = 'notifications'
        verbose_name = "Факт получения push"
        verbose_name_plural = "Факты получения push"
        ordering = ['-created_at']

    def __str__(self):
        who = self.user or self.fcm_token[:16]
        return f"[{self.created_at:%Y-%m-%d %H:%M}] {who} — {self.title or '(без заголовка)'}"


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
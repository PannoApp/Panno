from django.db import models
from django.conf import settings

class Event(models.Model):
    """
    Модель для хранения информации о мероприятиях (Афиша).
    """
    title = models.CharField(
        max_length=255, 
        verbose_name="Заголовок мероприятия"
    )
    description = models.TextField(
        verbose_name="Описание"
    )
    date_time = models.DateTimeField(
        verbose_name="Дата и время проведения"
    )
    image = models.ImageField(
        upload_to="events/images/", 
        verbose_name="Обложка"
    )
    FORMAT_CHOICES = [
        ('open', 'Открытое'),
        ('closed', 'Закрытое'),
    ]
    format = models.CharField(
        "Формат",
        max_length=10,
        choices=FORMAT_CHOICES,
        default='open',
    )
    price = models.DecimalField(
        "Цена входа",
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name="Активно"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Дата создания"
    )

    class Meta:
        verbose_name = "Мероприятие"
        verbose_name_plural = "Мероприятия"
        # По умолчанию сортируем по дате проведения (ближайшие вверху)
        ordering = ['date_time']

    def __str__(self):
        return f"{self.title} ({self.date_time})"


class News(models.Model):
    """
    Модель для хранения новостей заведения.
    """
    title = models.CharField(
        max_length=255, 
        verbose_name="Заголовок новости"
    )
    content = models.TextField(
        verbose_name="Текст новости"
    )
    image = models.ImageField(
        upload_to="news/images/", 
        verbose_name="Изображение", 
        null=True, 
        blank=True
    )
    created_at = models.DateTimeField(
        auto_now_add=True, 
        verbose_name="Дата публикации"
    )

    class Meta:
        verbose_name = "Новость"
        verbose_name_plural = "Новости"
        # Свежие новости всегда в начале
        ordering = ['-created_at']

    def __str__(self):
        return self.title
    
class EventReservation(models.Model):
    """
    Модель записи пользователя на конкретное мероприятие.
    """
    event = models.ForeignKey(
        'Event',
        on_delete=models.CASCADE,
        related_name='reservations',
        verbose_name='Мероприятие'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='events_reservations',
        verbose_name='Пользователь'
    )

    # Полезно знать, если пользователь берет с собой +1 или друзей
    guests_count = models.PositiveIntegerField(
        default=1,
        verbose_name='Количество гостей (включая себя)'
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата и время бронирования'
    )

    class Meta:
        verbose_name = "Запись на мероприятие"
        verbose_name_plural = "Записи на мероприятия"
        # Защита от дубликатов: один пользователь не может записаться на одно событие дважды
        unique_together = ('event', 'user')
        ordering = ['-created_at']

    def __str__(self):
        # Если у юзера нет имени, будет выводиться его email/телефон
        return f"Запись: {self.user} на {self.event.title}"

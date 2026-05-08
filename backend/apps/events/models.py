from django.db import models

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
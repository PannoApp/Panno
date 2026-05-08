from django.db import models
from django.conf import settings

class TableBooking(models.Model):
    """
    Модель для хранения информации о бронировании столов в ресторане.
    """

    # Список возможных статусов заявки
    STATUS_CHOICES = [
        ('pending', 'Ожидает подтверждения'),
        ('confirmed', 'Подтверждено'),
        ('canceled', 'Отменено'),
        ('completed', 'Завершено'),
    ]

    # Ссылка на пользователя, который сделал бронь. 
    # null=True позволяет создавать бронь администратору для гостей без аккаунта.
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='bookings',
        verbose_name="Пользователь",
        null=True,
        blank=True
    )

    # Имя гостя (может отличаться от имени в профиле пользователя)
    guest_name = models.CharField(
        max_length=255, 
        verbose_name="Имя гостя"
    )
    
    # Дата планируемого визита
    date = models.DateField(
        verbose_name="Дата"
    )
    
    # Время планируемого визита
    time = models.TimeField(
        verbose_name="Время"
    )
    
    # Количество гостей (целое положительное число)
    guests_count = models.PositiveIntegerField(
        verbose_name="Количество гостей"
    )
    
    # Поле для дополнительных пожеланий клиента
    comment = models.TextField(
        verbose_name="Комментарий", 
        blank=True, 
        null=True
    )
    
    # Текущий статус бронирования (по умолчанию "Ожидает подтверждения")
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name="Статус"
    )

    # Дата и время автоматического создания записи в БД
    created_at = models.DateTimeField(
        auto_now_add=True, 
        verbose_name="Дата создания"
    )

    class Meta:
        verbose_name = "Бронирование стола"
        verbose_name_plural = "Бронирования столов"
        # Сортировка: сначала отображаем самые ранние брони по дате и времени
        ordering = ['date', 'time']

    def __str__(self):
        return f"Бронь {self.guest_name} на {self.date} {self.time}"
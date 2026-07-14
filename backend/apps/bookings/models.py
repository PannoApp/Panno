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

    phone = models.CharField(
        "Телефон гостя",
        max_length=20,
        blank=True,
        default='',
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
    
    # Название зала — раньше был фиксированный список (main/terrace/private),
    # придуманный нами и не совпадавший с реальными залами ресторана. Теперь
    # это свободный текст, синхронизированный с реальными залами из Remarked
    # (см. remarked_room_id и apps/bookings/services.py::get_rooms).
    zone = models.CharField(
        "Зона/зал",
        max_length=100,
        blank=True,
        null=True,
    )

    # ID зала в Remarked (GetSlots.rooms[].id) — если гость выбрал конкретный
    # зал, используется в create_reserve_in_remarked для подбора свободного
    # стола именно в этом зале. Пусто — гость не указал зал, Remarked сам
    # подбирает стол по всему ресторану.
    remarked_room_id = models.BigIntegerField(
        "ID зала в Remarked",
        null=True,
        blank=True,
    )

    # ID конкретного стола в Remarked (GetSlots.rooms[].tables[].id) — гость
    # явно выбрал стол в UI (не «Любой стол»). Если заполнено — используется
    # в create_reserve_in_remarked напрямую, без автоподбора через
    # pick_table_for_room. Пусто — гость выбрал «Любой стол» (или зал вообще
    # не выбирал) — прежнее поведение автоподбора не меняется.
    # BigIntegerField, не IntegerField: реальные ID столов Remarked (в отличие
    # от легаси/виджетных, см. docs/remarked.md) — 14-значные числа
    # (например, 29646547874285), не помещаются в 32-битный IntegerField.
    remarked_table_id = models.BigIntegerField(
        "ID стола в Remarked",
        null=True,
        blank=True,
    )

    # Поле для дополнительных пожеланий клиента
    comment = models.TextField(
        verbose_name="Комментарий",
        blank=True,
        null=True,
    )
    
    # Текущий статус бронирования (по умолчанию "Ожидает подтверждения")
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name="Статус"
    )

    # ID брони в Remarked (CreateReserve.Response.reserve_id) — заполняется
    # асинхронно таской create_reserve_in_remarked после локального сохранения.
    remarked_reserve_id = models.IntegerField(
        "ID брони в Remarked",
        null=True,
        blank=True,
        unique=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Дата создания"
    )

    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="Дата обновления"
    )

    class Meta:
        verbose_name = "Бронирование стола"
        verbose_name_plural = "Бронирования столов"
        # Сортировка: сначала отображаем самые ранние брони по дате и времени
        ordering = ['date', 'time']
        indexes = [
            # Составной индекс для фильтрации по статусу + дате (основной admin-запрос)
            models.Index(fields=['status', 'date'], name='booking_status_date_idx'),
            # Одиночный индекс для фильтрации только по статусу (API-запросы, сигналы)
            models.Index(fields=['status'], name='booking_status_idx'),
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._original_status = self.status

    def __str__(self):
        return f"Бронь {self.guest_name} на {self.date} {self.time}"
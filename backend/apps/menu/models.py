from django.db import models

from utils.image_processing import AutoCropImageMixin
from utils.upload_paths import dish_image_upload, dish_video_upload, dish_video_processed_upload


class Category(models.Model):
    name = models.CharField("Название", max_length=100)
    order = models.PositiveIntegerField("Порядок отображения", default=0)

    class Meta:
        verbose_name = "Категория"
        verbose_name_plural = "Категории"
        ordering = ['order']

    def __str__(self):
        return self.name

class Tag(models.Model):
    name = models.CharField("Название тега", max_length=50)
    
    class Meta:
        verbose_name = "Тег"
        verbose_name_plural = "Теги"

    def __str__(self):
        return self.name

class Allergen(models.Model):
    name = models.CharField("Название аллергена", max_length=100)

    class Meta:
        verbose_name = "Аллерген"
        verbose_name_plural = "Аллергены"

    def __str__(self):
        return self.name

class Dish(AutoCropImageMixin, models.Model):
    _image_ratio = 16 / 9
    # Статусы обработки видео для видеоленты
    class VideoStatus(models.TextChoices):
        PENDING    = 'pending',    'Ожидает обработки'
        PROCESSING = 'processing', 'Обрабатывается'
        READY      = 'ready',      'Готово'
        FAILED     = 'failed',     'Ошибка'

    name = models.CharField("Название блюда", max_length=200)
    description = models.TextField("Описание", blank=True)
    price = models.DecimalField("Цена", max_digits=10, decimal_places=2)

    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE,
        related_name='dishes',
        verbose_name="Категория"
    )
    tags = models.ManyToManyField(Tag, blank=True, verbose_name="Теги")
    allergens = models.ManyToManyField(Allergen, blank=True, verbose_name="Аллергены")

    image = models.ImageField(
        "Фото",
        upload_to=dish_image_upload,
        help_text=(
            "Любой формат и ориентация — фото автоматически обрезается до 16:9 "
            "и конвертируется в JPEG. Рекомендуемый минимум: 1200×675 px."
        ),
    )
    # Оригинальное видео, загружаемое администратором
    video = models.FileField(
        "Видео (для ленты)",
        upload_to=dish_video_upload,
        blank=True,
        null=True,
        help_text=(
            "MP4 или MOV, вертикальное видео 9:16 (рекомендуется 720×1280). "
            "Будет автоматически транскодировано в фоне — статус виден в поле «Статус видео»."
        ),
    )
    # Видео после транскодирования (заполняется Celery-задачей)
    video_processed = models.FileField(
        "Обработанное видео",
        upload_to=dish_video_processed_upload,
        blank=True, null=True,
    )
    # Текущий этап обработки видео; индексируется для быстрой фильтрации ленты
    video_status = models.CharField(
        max_length=20,
        choices=VideoStatus.choices,
        default=VideoStatus.PENDING,
        db_index=True,
    )

    weight = models.PositiveIntegerField("Вес (г)", null=True, blank=True)
    story = models.TextField("История блюда", blank=True)
    is_active = models.BooleanField("Активно", default=True)

    class Meta:
        verbose_name = "Блюдо"
        verbose_name_plural = "Блюда"
        indexes = [
            # Составной индекс для быстрых запросов видеоленты (активные + готовое видео)
            models.Index(fields=['is_active', 'video_status']),
        ]

    def __str__(self):
        return self.name
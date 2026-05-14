import re
from django.utils import timezone
from django.db import models


class RestaurantInfo(models.Model):
    """
    Информация о ресторане (Singleton-модель).
    """
    address = models.CharField(max_length=500, verbose_name="Адрес")
    working_hours = models.CharField(
        max_length=500,
        verbose_name="Часы работы",
        help_text="Напр.: «Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00»",
    )
    # Временное уведомление об изменении режима — показывается поверх основных часов.
    # Примеры: «Закрыто 1 января», «В новогоднюю ночь работаем до 04:00».
    # Оставьте пустым, чтобы не показывать дополнительное сообщение.
    working_hours_note = models.CharField(
        "Временное изменение режима",
        max_length=500,
        blank=True,
        default='',
        help_text="Разовое уведомление, которое Flutter покажет гостям (напр.: «Закрыто 1 января»).",
    )
    tour_link = models.URLField(blank=True, null=True, verbose_name="Ссылка на 3D-тур")

    # Ссылки для кнопки «Построить маршрут» — приложение показывает те, что заполнены
    twogis_link       = models.URLField(blank=True, null=True, verbose_name="Ссылка на 2GIS")
    google_maps_link  = models.URLField(blank=True, null=True, verbose_name="Ссылка на Google Maps")
    yandex_maps_link  = models.URLField(blank=True, null=True, verbose_name="Ссылка на Яндекс.Карты")

    # URL для обратной связи (форма, email-ссылка mailto:, WhatsApp и т.п.)
    feedback_url = models.URLField("Обратная связь (URL)", blank=True, null=True)

    # Если ресторан требует депозит при бронировании — Flutter показывает предупреждение
    # и предлагает гостю позвонить менеджеру. Оплата через приложение не принимается.
    booking_deposit_required = models.BooleanField(
        "Требуется депозит при бронировании",
        default=False,
    )
    booking_deposit_note = models.CharField(
        "Текст предупреждения о депозите",
        max_length=500,
        blank=True,
        default='',
        help_text="Напр.: «При бронировании приват-зала необходим депозит. Позвоните менеджеру.»",
    )

    phone = models.CharField("Телефон", max_length=20, blank=True)
    whatsapp = models.CharField("WhatsApp", max_length=100, blank=True)
    telegram = models.CharField("Telegram", max_length=100, blank=True)
    instagram = models.CharField("Instagram", max_length=100, blank=True)

    concept_description = models.TextField("Описание концепции", blank=True, default='')
    hero_video_url = models.URLField("URL заглавного видео", max_length=500, blank=True, default='')

    visit_rules = models.TextField("Правила посещения", blank=True)
    privacy_policy = models.TextField("Политика обработки ПД", blank=True)
    terms_of_service = models.TextField("Пользовательское соглашение", blank=True)

    @property
    def is_open_now(self) -> bool:
        """
        Парсит working_hours вида "Пн–Вс: 12:00–00:00" и возвращает True,
        если текущее локальное время входит в указанный диапазон.
        Возвращает None при невозможности разобрать строку.
        """
        if not self.working_hours:
            return None
        match = re.search(r'(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})', self.working_hours)
        if not match:
            return None
        open_h, open_m, close_h, close_m = (int(x) for x in match.groups())
        now = timezone.localtime(timezone.now()).time()
        from datetime import time
        open_t = time(open_h, open_m)
        close_t = time(close_h, close_m)
        if close_t <= open_t:
            # Переход через полночь (например 20:00–02:00)
            return now >= open_t or now < close_t
        return open_t <= now < close_t

    class Meta:
        verbose_name = "Информация о ресторане"
        verbose_name_plural = "Информация о ресторане"

    def __str__(self):
        return "Информация о ресторане"

    def save(self, *args, **kwargs):
        """Гарантирует, что в базе будет только одна запись."""
        self.pk = 1
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        """Запрещает удаление информации."""
        pass

    @classmethod
    def load(cls):
        """Метод для получения синглтона."""
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class InteriorPhoto(models.Model):
    """
    Фотография интерьера ресторана для галереи во вкладке «Интерьер».
    Фотографии группируются по зонам (главный зал, бар, терраса и т.д.).
    """

    ZONE_CHOICES = [
        ('main_hall', 'Главный зал'),
        ('bar',       'Бар'),
        ('private',   'Приватная комната'),
        ('terrace',   'Терраса'),
        ('other',     'Другое'),
    ]

    zone    = models.CharField("Зона", max_length=20, choices=ZONE_CHOICES, default='main_hall')
    image   = models.ImageField("Фото", upload_to='interior/')
    caption = models.CharField("Подпись (необязательно)", max_length=255, blank=True)

    # Порядок отображения внутри зоны — меньше = раньше
    order   = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        verbose_name        = "Фото интерьера"
        verbose_name_plural = "Фото интерьера"
        ordering            = ['zone', 'order']

    def __str__(self):
        return f"{self.get_zone_display()} — {self.image.name}"


class AppVersion(models.Model):
    PLATFORM_CHOICES = [('ios', 'iOS'), ('android', 'Android')]

    platform       = models.CharField("Платформа", max_length=10, choices=PLATFORM_CHOICES, unique=True)
    min_version    = models.CharField("Минимальная версия (force update)", max_length=20)
    latest_version = models.CharField("Последняя версия (optional update)", max_length=20)
    store_url      = models.URLField("Ссылка на магазин", blank=True)
    updated_at     = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = "Версия приложения"
        verbose_name_plural = "Версии приложения"

    def __str__(self):
        return f"{self.platform}: min={self.min_version}, latest={self.latest_version}"


class HeroSlide(models.Model):
    """
    Слайды для заглавного экрана (карусель).
    """
    restaurant_info = models.ForeignKey(
        RestaurantInfo,
        on_delete=models.CASCADE,
        related_name='hero_slides',
        verbose_name="Ресторан"
    )
    image = models.ImageField("Изображение", upload_to='core/hero/')
    order = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        verbose_name = "Слайд главного экрана"
        verbose_name_plural = "Слайды главного экрана"
        ordering = ['order']

    def __str__(self):
        return f"Слайд {self.order}"
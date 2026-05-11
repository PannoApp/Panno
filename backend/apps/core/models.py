import re
from django.utils import timezone
from django.db import models


class RestaurantInfo(models.Model):
    """
    Информация о ресторане (Singleton-модель).
    """
    address = models.CharField(max_length=500, verbose_name="Адрес")
    working_hours = models.CharField(max_length=255, verbose_name="Часы работы")
    tour_link = models.URLField(blank=True, null=True, verbose_name="Ссылка на 3D-тур")
    twogis_link = models.URLField(blank=True, null=True, verbose_name="Ссылка на 2GIS")

    phone = models.CharField("Телефон", max_length=20, blank=True)
    whatsapp = models.CharField("WhatsApp", max_length=100, blank=True)
    telegram = models.CharField("Telegram", max_length=100, blank=True)
    instagram = models.CharField("Instagram", max_length=100, blank=True)

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
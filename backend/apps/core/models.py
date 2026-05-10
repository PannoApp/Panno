from django.db import models

class RestaurantInfo(models.Model):
    """
    Информация о ресторане (Singleton-модель).
    """
    address = models.CharField(max_length=500, verbose_name="Адрес")
    working_hours = models.CharField(max_length=255, verbose_name="Часы работы")
    tour_link = models.URLField(blank=True, null=True, verbose_name="Ссылка на 3D-тур")
    twogis_link = models.URLField(blank=True, null=True, verbose_name="Ссылка на 2GIS")

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
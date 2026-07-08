import re
from django.utils import timezone
from django.db import models

from utils.image_processing import AutoCropImageMixin
from utils.upload_paths import interior_image_upload, hero_image_upload
from utils.validators import validate_hero_image


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

    privacy_policy = models.TextField("Политика обработки ПД", blank=True)
    terms_of_service = models.TextField("Пользовательское соглашение", blank=True)

    def is_open_at(self, weekday: int, at_time) -> bool | None:
        """
        Парсит working_hours вида "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00" и возвращает True,
        если указанные (weekday, at_time) попадают в рабочие часы.
        weekday — 0=Пн..6=Вс (как у datetime.weekday()).
        Возвращает None при невозможности разобрать строку (не блокирует — см. вызывающий код).

        Используется и для `is_open_now` (текущий момент), и для валидации брони на
        произвольные дату/время в apps/bookings/serializers.py.
        """
        if not self.working_hours:
            return None

        # Нормализуем строку: приводим к нижнему регистру, заменяем длинные тире на дефисы
        normalized = self.working_hours.lower()
        normalized = normalized.replace('–', '-').replace('—', '-')

        # Разделяем на сегменты по запятым, точкам с запятой или переносам строк
        segments = re.split(r'[,;\n]', normalized)

        from datetime import time

        WEEKDAYS = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

        parsed_any = False
        is_open = False

        for segment in segments:
            segment = segment.strip()
            if not segment:
                continue

            # Ищем диапазон времени HH:MM-HH:MM
            time_match = re.search(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})', segment)
            if not time_match:
                continue

            parsed_any = True

            open_h, open_m, close_h, close_m = (int(x) for x in time_match.groups())
            open_t = time(open_h, open_m)
            close_t = time(close_h, close_m)

            # Извлекаем часть с днями недели, убрав время и двоеточия
            days_part = segment.replace(time_match.group(0), "").strip().strip(":")

            days = set()

            # Ищем диапазоны дней недели (например, пн-пт)
            day_ranges = re.findall(r'(пн|вт|ср|чт|пт|сб|вс)\s*-\s*(пн|вт|ср|чт|пт|сб|вс)', days_part)
            for start_day, end_day in day_ranges:
                start_idx = WEEKDAYS.index(start_day)
                end_idx = WEEKDAYS.index(end_day)
                if start_idx <= end_idx:
                    days.update(range(start_idx, end_idx + 1))
                else:
                    days.update(range(start_idx, 7))
                    days.update(range(0, end_idx + 1))
                # Удаляем распознанный диапазон
                days_part = days_part.replace(f"{start_day}-{end_day}", "")

            # Ищем отдельные дни
            individual_days = re.findall(r'(пн|вт|ср|чт|пт|сб|вс)', days_part)
            for d in individual_days:
                days.add(WEEKDAYS.index(d))

            # Если нет упоминаний никаких дней недели вообще в исходном сегменте,
            # считаем, что этот интервал применяется ко всем дням недели
            has_any_weekday_word = any(w in segment for w in WEEKDAYS)
            if not has_any_weekday_word:
                days = set(range(7))

            # Проверяем, попадает ли указанное время в интервал работы
            if close_t <= open_t:
                # Пересечение полуночи
                in_segment = (
                    (weekday in days and at_time >= open_t) or
                    ((weekday - 1) % 7 in days and at_time < close_t)
                )
            else:
                # В пределах одного дня
                in_segment = (weekday in days and open_t <= at_time < close_t)

            if in_segment:
                is_open = True

        if not parsed_any:
            return None

        return is_open

    @property
    def is_open_now(self) -> bool:
        """Как is_open_at, но для текущего локального момента времени."""
        now_dt = timezone.localtime(timezone.now())
        return self.is_open_at(now_dt.weekday(), now_dt.time())

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
        """Метод для получения синглтона. prefetch_related исключает N+1 при сериализации hero_slides."""
        obj, _ = cls.objects.prefetch_related('hero_slides').get_or_create(pk=1)
        return obj


class VisitRule(models.Model):
    """
    Правило посещения ресторана. Привязано к RestaurantInfo (singleton).
    Отображается в Flutter-приложении в разделе «Правила посещения».
    """
    restaurant_info = models.ForeignKey(
        RestaurantInfo,
        on_delete=models.CASCADE,
        related_name='visit_rules',
        verbose_name="Ресторан",
    )
    title = models.CharField("Название", max_length=100)
    body = models.TextField("Текст")
    order = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        ordering = ['order']
        verbose_name = "Правило посещения"
        verbose_name_plural = "Правила посещения"

    def __str__(self):
        return self.title


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
    image   = models.ImageField(
        "Фото",
        upload_to=interior_image_upload,
        help_text=(
            "Фото отображается fullscreen без обрезки. "
            "Рекомендуется горизонтальная ориентация, минимум 1200 px по ширине."
        ),
    )
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


class HeroSlide(AutoCropImageMixin, models.Model):
    _image_ratio = 16 / 9
    """
    Слайды для заглавного экрана (карусель).
    """
    restaurant_info = models.ForeignKey(
        RestaurantInfo,
        on_delete=models.CASCADE,
        related_name='hero_slides',
        verbose_name="Ресторан"
    )
    image = models.ImageField(
        "Изображение",
        upload_to=hero_image_upload,
        validators=[validate_hero_image],
        help_text=(
            "Любой формат и ориентация — автоматически обрезается до 16:9 "
            "и конвертируется в JPEG. Минимум 800×450 px, не более 10 МБ."
        ),
    )
    order = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        verbose_name = "Слайд главного экрана"
        verbose_name_plural = "Слайды главного экрана"
        ordering = ['order']

    def __str__(self):
        return f"Слайд {self.order}"
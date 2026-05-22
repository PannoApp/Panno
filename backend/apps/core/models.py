import re
from django.core.exceptions import ValidationError
from django.utils import timezone
from django.db import models


def validate_hero_image(image):
    """
    Проверяет, что загружаемое фото пригодно для hero-слайдера:
    - формат JPEG или PNG
    - минимальное разрешение 800 × 450 px
    - соотношение сторон от 1.5:1 до 2.4:1 (ландшафт, близко к 16:9)
    - размер файла не более 10 МБ
    """
    # Размер файла
    max_bytes = 10 * 1024 * 1024
    if hasattr(image, 'size') and image.size > max_bytes:
        raise ValidationError(
            f'Файл слишком большой ({image.size // (1024*1024)} МБ). Максимум — 10 МБ.'
        )

    # Формат
    name = getattr(image, 'name', '') or ''
    if not name.lower().endswith(('.jpg', '.jpeg', '.png')):
        raise ValidationError('Допустимые форматы: JPEG (.jpg) и PNG (.png).')

    # Размеры и соотношение сторон
    try:
        from PIL import Image as PilImage
        img = PilImage.open(image)
        w, h = img.size
        if w < 800 or h < 450:
            raise ValidationError(
                f'Слишком маленькое изображение ({w}×{h} px). '
                'Минимум — 800×450 px.'
            )
        ratio = w / h
        if not (1.5 <= ratio <= 2.4):
            raise ValidationError(
                f'Неподходящее соотношение сторон ({w}:{h} ≈ {ratio:.2f}:1). '
                'Нужно горизонтальное фото близко к 16:9 (соотношение от 1.5:1 до 2.4:1).'
            )
        # Сбрасываем указатель, чтобы Django смог сохранить файл после валидации
        image.seek(0)
    except ValidationError:
        raise
    except Exception:
        # Если Pillow недоступен или файл повреждён — пропускаем размерную проверку
        pass


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

    visit_rules = models.TextField("Правила посещения", blank=True)
    privacy_policy = models.TextField("Политика обработки ПД", blank=True)
    terms_of_service = models.TextField("Пользовательское соглашение", blank=True)

    @property
    def is_open_now(self) -> bool:
        """
        Парсит working_hours вида "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00" и возвращает True,
        если текущее локальное время входит в указанный диапазон.
        Возвращает None при невозможности разобрать строку.
        """
        if not self.working_hours:
            return None

        # Нормализуем строку: приводим к нижнему регистру, заменяем длинные тире на дефисы
        normalized = self.working_hours.lower()
        normalized = normalized.replace('–', '-').replace('—', '-')
        
        # Разделяем на сегменты по запятым, точкам с запятой или переносам строк
        segments = re.split(r'[,;\n]', normalized)
        
        from datetime import time
        
        # Получаем текущее локальное время и день недели
        now_dt = timezone.localtime(timezone.now())
        
        # Поддержка мокнутого времени в тестах
        if hasattr(now_dt, 'time') and callable(now_dt.time):
            current_time = now_dt.time()
        else:
            current_time = now_dt
            
        if hasattr(now_dt, 'weekday') and callable(now_dt.weekday):
            current_weekday = now_dt.weekday()
        else:
            current_weekday = getattr(now_dt, 'weekday', 0)
            if not isinstance(current_weekday, int):
                current_weekday = 0
        
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
                
            # Проверяем, попадает ли текущее время в интервал работы
            if close_t <= open_t:
                # Пересечение полуночи
                in_segment = (
                    (current_weekday in days and current_time >= open_t) or
                    ((current_weekday - 1) % 7 in days and current_time < close_t)
                )
            else:
                # В пределах одного дня
                in_segment = (current_weekday in days and open_t <= current_time < close_t)
                
            if in_segment:
                is_open = True
                
        if not parsed_any:
            return None
            
        return is_open

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
    image = models.ImageField(
        "Изображение",
        upload_to='core/hero/',
        validators=[validate_hero_image],
        help_text="JPEG или PNG, горизонтальное, минимум 800×450 px, не более 10 МБ.",
    )
    order = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        verbose_name = "Слайд главного экрана"
        verbose_name_plural = "Слайды главного экрана"
        ordering = ['order']

    def __str__(self):
        return f"Слайд {self.order}"
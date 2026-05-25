import io
import os

from django.core.files.base import ContentFile
from PIL import Image, ImageOps


def center_crop_to_ratio(
    image_field,
    ratio: float,
    max_width: int = 1200,
) -> ContentFile:
    """
    Читает изображение из storage (FieldFile) или из загруженного файла (UploadedFile),
    делает center-crop до нужного соотношения сторон, ресайзит до max_width
    и возвращает ContentFile с JPEG.

    centering=(0.5, 0.4) — чуть выше центра, чтобы лица/объекты попадали в кадр.
    """
    # FieldFile (уже на storage) vs UploadedFile (только что загружен, ещё не сохранён)
    if hasattr(image_field, 'open'):
        with image_field.open('rb') as f:
            data = f.read()
    else:
        image_field.seek(0)
        data = image_field.read()

    img = Image.open(io.BytesIO(data))
    img.load()
    img = img.convert('RGB')  # убрать альфа-канал PNG / WEBP

    w, h = img.size
    target_h = int(w / ratio)
    if target_h <= h:
        target_w = w
    else:
        target_h = h
        target_w = int(h * ratio)

    img = ImageOps.fit(
        img,
        (target_w, target_h),
        method=Image.LANCZOS,
        centering=(0.5, 0.4),
    )

    if img.width > max_width:
        new_h = int(max_width / img.width * img.height)
        img = img.resize((max_width, new_h), Image.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=85, optimize=True)
    buf.seek(0)
    return ContentFile(buf.read())


class AutoCropImageMixin:
    """
    Миксин для Django-моделей с полем-изображением.

    Использование:
        class Event(AutoCropImageMixin, models.Model):
            _image_ratio = 16 / 9   # целевой ratio (ширина / высота)
            _image_field = 'image'  # имя поля (по умолчанию 'image')
            image = models.ImageField(...)

    При каждом сохранении с новым/изменившимся изображением:
    - делает center-crop до _image_ratio
    - ресайзит до 1200px по ширине
    - конвертирует в JPEG
    - перезаписывает файл в storage и обновляет DB (без рекурсивного save)
    """

    _image_ratio: float = 16 / 9
    _image_field: str = 'image'

    def save(self, *args, **kwargs):
        update_fields = kwargs.get('update_fields')
        # Если вызов через update_fields — это наше собственное обновление, пропускаем
        if update_fields is not None:
            super().save(*args, **kwargs)
            return

        field = getattr(self, self._image_field)

        # Определяем, изменилось ли изображение
        old_name = None
        if self.pk:
            try:
                old_obj = self.__class__.objects.get(pk=self.pk)
                old_field = getattr(old_obj, self._image_field)
                old_name = old_field.name if old_field else None
            except self.__class__.DoesNotExist:
                pass

        current_name = field.name if field else None
        image_changed = bool(field) and (self.pk is None or current_name != old_name)

        # Сначала сохраняем модель — оригинальный файл записывается в storage
        super().save(*args, **kwargs)

        if not image_changed:
            return

        # Перечитываем поле после save (теперь это FieldFile в storage)
        field = getattr(self, self._image_field)
        if not field or not field.name:
            return

        processed = center_crop_to_ratio(field, self._image_ratio)

        base_name = os.path.splitext(os.path.basename(field.name))[0]
        # Pass only the filename so generate_filename adds upload_to exactly once.
        # Passing the full path (including upload_to) would double it in storage.
        new_name = base_name + '.jpg'

        # Удаляем оригинал и записываем обработанный файл
        field.delete(save=False)
        field.save(new_name, processed, save=False)

        # Обновляем только поле image в DB без рекурсивного save()
        self.__class__.objects.filter(pk=self.pk).update(
            **{self._image_field: field.name}
        )

        # django-cleanup's cache was set to the original filename by post_save above.
        # The .update() call above bypasses signals, so we manually refresh the cache
        # so that subsequent updates know which processed JPEG to delete.
        try:
            from django_cleanup import cleanup as _cleanup
            _cleanup.refresh(self)
        except ImportError:
            pass

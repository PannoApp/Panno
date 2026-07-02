from django.core.exceptions import ValidationError


def validate_hero_image(image):
    """
    Проверяет, что загружаемое фото пригодно для hero-слайдера:
    - формат JPEG или PNG
    - минимальное разрешение 800 × 450 px
    - соотношение сторон от 1.5:1 до 2.4:1 (ландшафт, близко к 16:9)
    - размер файла не более 10 МБ
    """
    max_bytes = 10 * 1024 * 1024
    if hasattr(image, 'size') and image.size > max_bytes:
        raise ValidationError(
            f'Файл слишком большой ({image.size // (1024*1024)} МБ). Максимум — 10 МБ.'
        )

    name = getattr(image, 'name', '') or ''
    if not name.lower().endswith(('.jpg', '.jpeg', '.png')):
        raise ValidationError('Допустимые форматы: JPEG (.jpg) и PNG (.png).')

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
        image.seek(0)
    except ValidationError:
        raise
    except Exception:
        pass

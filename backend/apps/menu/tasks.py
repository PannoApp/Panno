import os
import tempfile
import logging

import ffmpeg
from celery import shared_task
from django.core.files.base import File

logger = logging.getLogger(__name__)


@shared_task(
    bind=True,
    max_retries=2,          # максимум 2 повторные попытки при ошибке FFmpeg
    time_limit=900,         # жёсткий лимит — задача убивается через 15 минут
    soft_time_limit=840,    # мягкий лимит — SoftTimeLimitExceeded за 14 минут, чтобы успеть завершить
    acks_late=True,         # подтверждать задачу только после успешного выполнения
)
def process_dish_video(self, dish_id: int):
    """
    Транскодирует оригинальное видео блюда в формат H.264/AAC 720×1280
    и сохраняет результат в поле video_processed.

    Шаги:
    1. Получить объект Dish из БД.
    2. Установить статус PROCESSING.
    3. Запустить FFmpeg: масштаб 720×1280 с letterbox, CRF=28, faststart.
    4. Сохранить готовый файл и установить статус READY.
    5. При ошибке FFmpeg — установить FAILED и поставить задачу в очередь повторно.
    """
    from .models import Dish

    # Если блюдо удалено — тихо выходим
    try:
        dish = Dish.objects.get(pk=dish_id)
    except Dish.DoesNotExist:
        return

    # Помечаем, что обработка началась, чтобы API не отдавал сырое видео
    dish.video_status = Dish.VideoStatus.PROCESSING
    dish.save(update_fields=['video_status'])

    # Для FileSystemStorage получаем путь напрямую.
    # S3Storage не поддерживает .path — скачиваем во временный файл.
    src_tmp_path = None
    try:
        src_path = dish.video.path
    except NotImplementedError:
        ext = os.path.splitext(dish.video.name)[1]
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as src_tmp:
            src_tmp.write(dish.video.read())
            src_tmp_path = src_tmp.name
        src_path = src_tmp_path

    # Создаём временный файл для результата; FFmpeg запишет в него транскодированное видео
    with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as tmp:
        out_path = tmp.name

    try:
        (
            ffmpeg
            .input(src_path)
            .output(
                out_path,
                vcodec='libx264',       # видеокодек H.264 — широкая совместимость
                acodec='aac',           # аудиокодек AAC
                vf=(
                    'scale=720:1280:force_original_aspect_ratio=decrease,'
                    'pad=720:1280:(ow-iw)/2:(oh-ih)/2'  # letterbox для сохранения пропорций
                ),
                crf=28,                 # качество: 0=лучшее, 51=худшее; 28 — баланс размер/качество
                preset='fast',          # скорость кодирования (fast — компромисс между скоростью и сжатием)
                movflags='+faststart',  # перемещает метаданные в начало файла для стриминга
                audio_bitrate='128k',   # битрейт аудио
                y=None,                 # перезаписывать выходной файл без подтверждения
            )
            .run(capture_stdout=True, capture_stderr=True)
        )

        # Сохраняем готовое видео в поле модели
        with open(out_path, 'rb') as f:
            dish.video_processed.save(
                f'dish_{dish_id}_processed.mp4', File(f), save=False
            )
        dish.video_status = Dish.VideoStatus.READY
        dish.save(update_fields=['video_processed', 'video_status'])

    except ffmpeg.Error as exc:
        # Декодируем stderr FFmpeg для диагностики в логах
        logger.error("FFmpeg error dish %s: %s", dish_id, exc.stderr.decode())
        Dish.objects.filter(pk=dish.pk).update(video_status=Dish.VideoStatus.FAILED)
        # Повторяем задачу через 60 секунд (максимум max_retries раз)
        raise self.retry(exc=exc, countdown=60)

    finally:
        # Удаляем временные файлы в любом случае, чтобы не засорять диск
        os.unlink(out_path)
        if src_tmp_path:
            os.unlink(src_tmp_path)

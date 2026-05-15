import time
import logging 
from celery import shared_task

logger = logging.getLogger(__name__)

@shared_task(name='apps.core.tasks.test_celery_task')
def test_celery_task(word: str):
    """
    Тестовая фоновая задача. 
    Имитирует долгий процесс (например, отправку письма или пуша).
    """
    logger.info(f"[{word}] Фоновая задача запущена...")
    
    # Искусственная задержка в 5 секунд
    time.sleep(5) 
    
    logger.info(f"[{word}] Фоновая задача успешно завершена!")
    return f"Успех: {word}"
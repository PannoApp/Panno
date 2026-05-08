import boto3
from django.conf import settings
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger(__name__)

class S3Service:
    """
    Сервис для прямой работы с S3 хранилищем через boto3.
    Используется там, где недостаточно стандартных средств Django.
    """

    def __init__(self):
        # Инициализируем сессию и клиент boto3, используя наши настройки
        self.session = boto3.session.Session()
        self.client = self.session.client(
            service_name='s3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            endpoint_url=settings.AWS_S3_ENDPOINT_URL,
            region_name=settings.AWS_S3_REGION_NAME,
        )
        self.bucket_name = settings.AWS_STORAGE_BUCKET_NAME

    def get_presigned_url(self, object_name: str, expiration: int = 3600) -> str:
        """
        Генерирует временную (presigned) ссылку на объект.
        Полезно для доступа к приватным файлам.
        """
        try:
            response = self.client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': object_name},
                ExpiresIn=expiration
            )
        except ClientError as e:
            logger.error(f"Ошибка при генерации S3 ссылки: {e}")
            return ""
        return response

    def delete_file(self, object_name: str) -> bool:
        """
        Удаляет файл из бакета по его ключу (пути).
        """
        try:
            self.client.delete_object(Bucket=self.bucket_name, Key=object_name)
            return True
        except ClientError as e:
            logger.error(f"Ошибка при удалении файла из S3: {e}")
            return False
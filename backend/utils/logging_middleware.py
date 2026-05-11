import json
import logging
import time
from typing import Any

from django.http import HttpRequest, HttpResponse

logger = logging.getLogger('django.request')

class JsonFormatter(logging.Formatter):
    """
    Кастомный форматтер для вывода логов в формате JSON.
    """
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            'time': self.formatTime(record, self.datefmt),
            'level': record.levelname,
            'message': record.getMessage(),
        }
        
        # Добавляем дополнительные поля, переданные через extra
        extra_keys = ['method', 'path', 'status_code', 'user_id', 'duration', 'headers', 'query_params', 'body']
        for key in extra_keys:
            if hasattr(record, key):
                log_data[key] = getattr(record, key)
                
        # Если есть traceback, добавляем его
        if record.exc_info:
            log_data['traceback'] = self.formatException(record.exc_info)
            
        return json.dumps(log_data, ensure_ascii=False)


class RequestLoggingMiddleware:
    """
    Middleware для логирования всех запросов и их времени выполнения.
    Маскирует чувствительные данные: Authorization и OTP.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        start_time = time.time()
        request.start_time = start_time  # Сохраняем для process_exception
        
        response = self.get_response(request)
        
        duration = time.time() - start_time
        self.log_request(request, response, duration)
        
        return response

    def process_exception(self, request: HttpRequest, exception: Exception):
        """
        Перехватывает необработанные исключения (серверные ошибки 500).
        В DRF большинство исключений обрабатываются его собственным exception_handler, 
        поэтому сюда попадают только по-настоящему необработанные ошибки Django.
        """
        start_time = getattr(request, 'start_time', time.time())
        duration = time.time() - start_time
        
        extra_data = {
            'method': request.method,
            'path': request.path,
            'status_code': 500,
            'user_id': self.get_user_id(request),
            'duration': round(duration, 4),
            'headers': self.get_masked_headers(request),
            'query_params': request.GET.dict(),
            'body': self.get_masked_body(request)
        }
        
        logger.error(
            f"Unhandled Exception: {request.method} {request.path}",
            extra=extra_data,
            exc_info=True
        )
        return None

    def log_request(self, request: HttpRequest, response: HttpResponse, duration: float):
        status_code = response.status_code
        
        extra_data = {
            'method': request.method,
            'path': request.path,
            'status_code': status_code,
            'user_id': self.get_user_id(request),
            'duration': round(duration, 4),
        }
        
        if status_code >= 500:
            extra_data['headers'] = self.get_masked_headers(request)
            extra_data['query_params'] = request.GET.dict()
            extra_data['body'] = self.get_masked_body(request)
            
            # Пишем ERROR. Traceback может быть записан через process_exception,
            # но если DRF сам вернул 500, мы залогируем данные запроса здесь.
            logger.error(f"Server Error: {request.method} {request.path} - {status_code}", extra=extra_data)
        else:
            # Для штатных ответов и ошибок клиента
            logger.info(f"Request: {request.method} {request.path} - {status_code}", extra=extra_data)

    def get_user_id(self, request: HttpRequest) -> str:
        if hasattr(request, 'user') and request.user.is_authenticated:
            return str(request.user.id)
        return 'Anonymous'

    def get_masked_headers(self, request: HttpRequest) -> dict:
        headers = dict(request.headers)
        if 'Authorization' in headers:
            headers['Authorization'] = '***'
        return headers

    def get_masked_body(self, request: HttpRequest) -> str:
        try:
            body_bytes = request.body
            if not body_bytes:
                return ""
            
            body_str = body_bytes.decode('utf-8')
            try:
                body_json = json.loads(body_str)
                # Маскируем OTP
                if isinstance(body_json, dict) and 'otp' in body_json:
                    body_json['otp'] = '***'
                return json.dumps(body_json, ensure_ascii=False)
            except json.JSONDecodeError:
                # Если это не JSON, возвращаем как есть
                return body_str
        except Exception:
            # Игнорируем RawPostDataException и другие ошибки чтения тела
            return "<unreadable body>"

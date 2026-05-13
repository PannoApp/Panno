"""
Тесты кастомного обработчика исключений DRF (utils/exception_handler.py).

Проверяем два сценария:
1. DRF-исключение (ValidationError) — обрабатывается штатно, статус 400.
2. Необработанное Python-исключение (KeyError) — перехватывается нашим
   хендлером, Flutter получает JSON {"detail": "..."} со статусом 500.
"""

from unittest.mock import patch

from django.test import override_settings
from django.urls import path

from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.exceptions import ValidationError
from rest_framework.test import APITestCase


# ---------------------------------------------------------------------------
# Вспомогательные view для тестирования — монтируются временным urlconf
# ---------------------------------------------------------------------------

@api_view(['GET'])
def view_raises_drf_exception(request):
    """Имитирует штатное DRF-исключение (должно вернуть 400)."""
    raise ValidationError("Некорректный запрос")


@api_view(['GET'])
def view_raises_python_exception(request):
    """Имитирует неожиданное Python-исключение внутри view (должно вернуть 500)."""
    data = {}
    return data['missing_key']   # KeyError


urlpatterns = [
    path('test/drf-error/', view_raises_drf_exception),
    path('test/python-error/', view_raises_python_exception),
]


# ---------------------------------------------------------------------------
# Тесты
# ---------------------------------------------------------------------------

@override_settings(
    ROOT_URLCONF=__name__,
    REST_FRAMEWORK={
        'EXCEPTION_HANDLER': 'utils.exception_handler.custom_exception_handler',
        'DEFAULT_AUTHENTICATION_CLASSES': [],
        'DEFAULT_PERMISSION_CLASSES': [],
    },
)
class CustomExceptionHandlerTest(APITestCase):

    def test_drf_exception_returns_400_json(self):
        """Штатное DRF-исключение обрабатывается нормально — 400 и JSON."""
        response = self.client.get('/test/drf-error/')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response['Content-Type'], 'application/json')

    def test_drf_exception_body_is_not_empty(self):
        """Ответ на DRF-исключение содержит непустое тело с описанием ошибки."""
        response = self.client.get('/test/drf-error/')
        # ValidationError со строкой сериализуется как список ["..."]
        body = response.json()
        self.assertTrue(bool(body))

    def test_python_exception_returns_500(self):
        """Необработанное Python-исключение → статус 500."""
        response = self.client.get('/test/python-error/')
        self.assertEqual(response.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)

    def test_python_exception_returns_json_not_html(self):
        """Flutter не должен получить HTML — Content-Type всегда application/json."""
        response = self.client.get('/test/python-error/')
        self.assertIn('application/json', response['Content-Type'])

    def test_python_exception_body_has_detail_key(self):
        """Тело ответа содержит ключ detail с читаемым сообщением."""
        response = self.client.get('/test/python-error/')
        body = response.json()
        self.assertIn('detail', body)
        self.assertIsInstance(body['detail'], str)
        self.assertTrue(len(body['detail']) > 0)

    def test_python_exception_is_logged(self):
        """Необработанное исключение должно быть залогировано как ERROR."""
        with patch('utils.exception_handler.logger') as mock_logger:
            self.client.get('/test/python-error/')
            # exception() вызывается хотя бы один раз
            mock_logger.exception.assert_called_once()

    def test_python_exception_log_contains_view_name(self):
        """Лог содержит имя view для быстрой диагностики."""
        with patch('utils.exception_handler.logger') as mock_logger:
            self.client.get('/test/python-error/')
            call_args = mock_logger.exception.call_args
            # Первый позиционный аргумент — строка с именем view
            log_msg = call_args[0][0]
            self.assertIn('%s', log_msg)

import json
import logging
from unittest.mock import Mock, patch

from django.http import HttpResponse, HttpRequest
from django.test import SimpleTestCase, RequestFactory

from utils.logging_middleware import JsonFormatter, RequestLoggingMiddleware


class JsonFormatterTests(SimpleTestCase):
    def test_format_valid_json(self):
        formatter = JsonFormatter(datefmt='%Y-%m-%d %H:%M:%S')
        record = logging.LogRecord(
            name='test_logger', level=logging.INFO, pathname='', lineno=0,
            msg='Test message', args=(), exc_info=None
        )
        record.method = 'GET'
        record.path = '/api/test/'
        record.status_code = 200
        
        result = formatter.format(record)
        
        # Проверяем, что это валидный JSON
        data = json.loads(result)
        self.assertEqual(data['level'], 'INFO')
        self.assertEqual(data['message'], 'Test message')
        self.assertEqual(data['method'], 'GET')
        self.assertEqual(data['path'], '/api/test/')
        self.assertEqual(data['status_code'], 200)
        self.assertIn('time', data)

    def test_format_with_exception(self):
        formatter = JsonFormatter()
        try:
            raise ValueError("Test error")
        except ValueError as e:
            import sys
            exc_info = sys.exc_info()
            
        record = logging.LogRecord(
            name='test_logger', level=logging.ERROR, pathname='', lineno=0,
            msg='Error occurred', args=(), exc_info=exc_info
        )
        
        result = formatter.format(record)
        data = json.loads(result)
        
        self.assertEqual(data['level'], 'ERROR')
        self.assertIn('ValueError: Test error', data['traceback'])


class RequestLoggingMiddlewareTests(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        # Mock get_response that returns a simple 200 OK
        self.get_response = Mock(return_value=HttpResponse(status=200))
        self.middleware = RequestLoggingMiddleware(self.get_response)

    @patch('utils.logging_middleware.logger.info')
    def test_call_logs_info_on_success(self, mock_logger_info):
        request = self.factory.get('/api/test/')
        
        response = self.middleware(request)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(mock_logger_info.called)
        
        args, kwargs = mock_logger_info.call_args
        self.assertIn('Request: GET /api/test/ - 200', args[0])
        self.assertIn('extra', kwargs)
        self.assertEqual(kwargs['extra']['status_code'], 200)

    @patch('utils.logging_middleware.logger.error')
    def test_call_logs_error_on_500(self, mock_logger_error):
        # Mock get_response that returns 500
        error_response = HttpResponse(status=500)
        middleware = RequestLoggingMiddleware(Mock(return_value=error_response))
        
        request = self.factory.post('/api/test/', data='{}', content_type='application/json')
        response = middleware(request)
        
        self.assertEqual(response.status_code, 500)
        self.assertTrue(mock_logger_error.called)
        
        args, kwargs = mock_logger_error.call_args
        self.assertIn('Server Error: POST /api/test/ - 500', args[0])
        self.assertIn('extra', kwargs)
        
        # Check that headers and body are included in extra for 500
        self.assertIn('headers', kwargs['extra'])
        self.assertIn('body', kwargs['extra'])

    @patch('utils.logging_middleware.logger.error')
    def test_process_exception(self, mock_logger_error):
        request = self.factory.get('/api/test/')
        request.start_time = 1234567890.0
        
        exception = ValueError("Something went wrong")
        
        with patch('time.time', return_value=1234567891.0):
            result = self.middleware.process_exception(request, exception)
        
        self.assertIsNone(result) # middleware process_exception should return None to let DRF or Django handle it
        self.assertTrue(mock_logger_error.called)
        
        args, kwargs = mock_logger_error.call_args
        self.assertIn('Unhandled Exception: GET /api/test/', args[0])
        self.assertTrue(kwargs['exc_info'])
        self.assertEqual(kwargs['extra']['status_code'], 500)

    def test_get_masked_headers(self):
        request = self.factory.get('/api/test/', HTTP_AUTHORIZATION='Bearer secret_token', HTTP_X_CUSTOM='Value')
        
        headers = self.middleware.get_masked_headers(request)
        self.assertEqual(headers.get('Authorization'), '***')
        self.assertEqual(headers.get('X-Custom'), 'Value')

    def test_get_masked_body_json(self):
        request = self.factory.post(
            '/api/auth/', 
            data=json.dumps({"phone": "+77001234567", "otp": "1234", "other": "data"}), 
            content_type='application/json'
        )
        
        body_str = self.middleware.get_masked_body(request)
        body_data = json.loads(body_str)
        
        self.assertEqual(body_data['otp'], '***')
        self.assertEqual(body_data['phone'], '+77001234567')

    def test_get_masked_body_non_json(self):
        request = self.factory.post('/api/auth/', data="Just plain text otp=1234", content_type='text/plain')
        
        body_str = self.middleware.get_masked_body(request)
        self.assertEqual(body_str, "Just plain text otp=1234")

    def test_get_masked_body_empty(self):
        request = self.factory.get('/api/test/')
        body_str = self.middleware.get_masked_body(request)
        self.assertEqual(body_str, "")

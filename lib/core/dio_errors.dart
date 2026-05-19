import 'package:dio/dio.dart';

/// Преобразует исключение в читаемую русскую строку для отображения пользователю.
/// DioException типы маппируются на контекстные сообщения; остальное — generic фраза.
String dioErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Нет соединения';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status >= 500) return 'Сервер временно недоступен';
        if (status >= 400) {
          final data = error.response?.data;
          if (data is Map) {
            final msg =
                data['message'] ?? data['detail'] ?? data['error'];
            if (msg is String && msg.isNotEmpty) return msg;
          }
          return 'Ошибка запроса';
        }
      default:
        break;
    }
  }
  return 'Что-то пошло не так';
}

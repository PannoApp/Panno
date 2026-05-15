import logging

from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger('django.request')


def custom_exception_handler(exc, context):
    """
    Кастомный обработчик исключений DRF.

    Если DRF не умеет обработать исключение (возвращает None — т.е. это
    не APIException, а KeyError / AttributeError / и т.п.), перехватываем
    его здесь: логируем traceback и отдаём Flutter стандартный JSON 500
    вместо HTML-страницы Django или пустого тела.
    """
    response = exception_handler(exc, context)

    if response is None:
        # DRF не распознал исключение — это необработанная серверная ошибка
        view = context.get('view')
        logger.exception(
            "Необработанное исключение в %s",
            view.__class__.__name__ if view else 'unknown view',
            exc_info=exc,
        )
        return Response(
            {"detail": "Внутренняя ошибка сервера."},
            status=500,
        )

    return response

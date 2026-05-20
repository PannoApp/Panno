import json
import logging

from django.conf import settings
from django.http import JsonResponse
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiParameter, OpenApiResponse
from drf_spectacular.types import OpenApiTypes
from utils.idempotency import IdempotencyMixin
from utils.pagination import StandardPagination
from .models import TableBooking
from .serializers import TableBookingSerializer
from .tasks import _build_booking_html, _tg_post

logger = logging.getLogger(__name__)


_error_401 = OpenApiResponse(description='Токен не передан или недействителен')

_pagination_params = [
    OpenApiParameter(
        name='page',
        type=OpenApiTypes.INT,
        location=OpenApiParameter.QUERY,
        description='Номер страницы',
        required=False,
    ),
    OpenApiParameter(
        name='page_size',
        type=OpenApiTypes.INT,
        location=OpenApiParameter.QUERY,
        description='Количество записей на странице (по умолчанию 20, максимум 100)',
        required=False,
    ),
]


@extend_schema(tags=['Bookings'])
class TableBookingListCreateView(IdempotencyMixin, generics.ListCreateAPIView):
    serializer_class = TableBookingSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardPagination

    @extend_schema(
        summary='Список моих бронирований столов',
        description=(
            'Возвращает все бронирования текущего авторизованного пользователя, '
            'отсортированные по дате и времени визита (ближайшие первыми).'
        ),
        parameters=_pagination_params,
        responses={
            200: TableBookingSerializer(many=True),
            401: _error_401,
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        summary='Создать бронирование стола',
        description=(
            'Создаёт новое бронирование стола для текущего авторизованного пользователя.\n\n'
            'Статус нового бронирования автоматически устанавливается в `pending` '
            '(ожидает подтверждения).\n\n'
            '**Ограничения:** количество гостей от 1 до 50.'
        ),
        request=TableBookingSerializer,
        responses={
            201: TableBookingSerializer,
            400: OpenApiResponse(
                description='Ошибка валидации входных данных',
                examples=[
                    OpenApiExample(
                        'Превышен лимит гостей',
                        value={'guests_count': ['Убедитесь, что это значение меньше либо равно 50.']},
                    ),
                    OpenApiExample(
                        'Обязательное поле',
                        value={'guest_name': ['Обязательное поле.']},
                    ),
                ],
            ),
            401: _error_401,
        },
        examples=[
            OpenApiExample(
                'Бронирование на 4 гостей',
                value={
                    'guest_name': 'Алихан Сейткали',
                    'date': '2026-06-15',
                    'time': '19:30:00',
                    'guests_count': 4,
                    'comment': 'Аллергия на орехи, нужен детский стул',
                },
                request_only=True,
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return TableBooking.objects.none()
        return TableBooking.objects.filter(user=self.request.user).order_by('-date', '-time')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


@method_decorator(csrf_exempt, name='dispatch')
class TelegramWebhookView(View):
    """
    Принимает callback_query от Telegram при нажатии inline-кнопок
    «Подтвердить» / «Отменить» в уведомлениях о бронировании.
    """

    def post(self, request):
        token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
        if not token:
            return JsonResponse({'ok': False}, status=500)

        secret = getattr(settings, 'TELEGRAM_WEBHOOK_SECRET', '')
        if secret and request.headers.get('X-Telegram-Bot-Api-Secret-Token', '') != secret:
            return JsonResponse({'ok': False}, status=403)

        try:
            data = json.loads(request.body)
        except (json.JSONDecodeError, ValueError):
            return JsonResponse({'ok': False}, status=400)

        callback_query = data.get('callback_query')
        if not callback_query:
            return JsonResponse({'ok': True})

        callback_id = callback_query['id']
        callback_data = callback_query.get('data', '')
        message = callback_query.get('message', {})
        chat_id = message.get('chat', {}).get('id')
        message_id = message.get('message_id')

        parts = callback_data.split(':', 1)
        if len(parts) != 2 or parts[0] not in ('confirm', 'cancel'):
            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Неизвестная команда'}, token)
            return JsonResponse({'ok': True})

        action, booking_id_str = parts
        try:
            booking = TableBooking.objects.select_related('user').get(pk=int(booking_id_str))
        except (TableBooking.DoesNotExist, ValueError):
            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Бронирование не найдено'}, token)
            return JsonResponse({'ok': True})

        if booking.status != 'pending':
            _tg_post('answerCallbackQuery', {
                'callback_query_id': callback_id,
                'text': f'Уже обработано: {booking.get_status_display()}',
                'show_alert': True,
            }, token)
            return JsonResponse({'ok': True})

        if action == 'confirm':
            booking.status = 'confirmed'
            status_label = '✅ <b>Подтверждено администратором</b>'
            answer_text = 'Бронирование подтверждено'
        else:
            booking.status = 'canceled'
            status_label = '❌ <b>Отменено администратором</b>'
            answer_text = 'Бронирование отменено'

        booking.save()

        _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': answer_text}, token)

        if chat_id and message_id:
            _tg_post('editMessageText', {
                'chat_id': chat_id,
                'message_id': message_id,
                'text': _build_booking_html(booking, status_label=status_label),
                'parse_mode': 'HTML',
                'reply_markup': {'inline_keyboard': []},
            }, token)

        logger.info("Telegram webhook: booking=%s action=%s", booking_id_str, action)
        return JsonResponse({'ok': True})

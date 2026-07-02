import html
import json
import logging
import requests

from django.core.cache import cache

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


def _get_manager_keyboard():
    return {
        'keyboard': [
            [{'text': '📢 Отправить пуш'}],
        ],
        'resize_keyboard': True,
    }



@method_decorator(csrf_exempt, name='dispatch')
class TelegramWebhookView(View):
    """
    Принимает callback_query от Telegram при нажатии inline-кнопок
    «Подтвердить» / «Отменить» в уведомлениях о бронировании,
    а также обрабатывает рассылку push-уведомлений через меню менеджера.
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

        # 1. Обработка callback_query (кнопки подтверждения / отмены)
        callback_query = data.get('callback_query')
        if callback_query:
            return self.handle_callback_query(request, callback_query, token)

        # 2. Обработка обычных сообщений (команды, FSM ввод)
        message = data.get('message')
        if message:
            return self.handle_message(request, message, token)

        return JsonResponse({'ok': True})

    def handle_callback_query(self, request, callback_query, token):
        callback_id = callback_query['id']
        callback_data = callback_query.get('data', '')
        message = callback_query.get('message', {})
        chat_id = message.get('chat', {}).get('id')
        message_id = message.get('message_id')

        parts = callback_data.split(':', 1)
        if len(parts) != 2 or parts[0] not in ('confirm', 'cancel', 'bulk_push', 'push_category'):
            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Неизвестная команда'}, token)
            return JsonResponse({'ok': True})

        # Обработка подтверждения/отмены push-рассылки от бота
        if parts[0] == 'bulk_push':
            action = parts[1]
            cache_key = f"tg_fsm:{chat_id}"
            state_data = cache.get(cache_key)

            if not state_data or state_data.get('state') != 'waiting_for_confirmation':
                _tg_post('answerCallbackQuery', {
                    'callback_query_id': callback_id,
                    'text': 'Время ожидания истекло или рассылка уже отправлена.',
                    'show_alert': True,
                }, token)
                return JsonResponse({'ok': True})

            if action == 'cancel':
                cache.delete(cache_key)
                _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Рассылка отменена.'}, token)
                _tg_post('editMessageText', {
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'text': '❌ Отправка рассылки отменена.',
                }, token)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Вы можете начать заново в любое время.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
                return JsonResponse({'ok': True})

            elif action == 'confirm':
                title = state_data['data']['title']
                body = state_data['data']['body']
                category = state_data['data'].get('category', '')
                cache.delete(cache_key)

                # Отправляем запрос на наш API эндпоинт
                url = request.build_absolute_uri('/api/v1/notifications/send-push-via-bot/')
                headers = {}
                secret = getattr(settings, 'TELEGRAM_WEBHOOK_SECRET', '')
                if secret:
                    headers['X-Telegram-Bot-Api-Secret-Token'] = secret

                payload = {
                    'manager_telegram_id': str(chat_id),
                    'title': title,
                    'body': body,
                    'category': category,
                }

                try:
                    resp = requests.post(url, json=payload, headers=headers, timeout=10)
                    if resp.status_code == 202:
                        _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Рассылка успешно запущена!'}, token)
                        _tg_post('editMessageText', {
                            'chat_id': chat_id,
                            'message_id': message_id,
                            'text': f"✅ <b>Рассылка успешно запущена!</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(body)}",
                            'parse_mode': 'HTML',
                        }, token)
                        _tg_post('sendMessage', {
                            'chat_id': chat_id,
                            'text': 'Вы можете создать новую рассылку в любое время.',
                            'reply_markup': _get_manager_keyboard()
                        }, token)
                        return JsonResponse({'ok': True})
                    else:
                        raise Exception(f"API returned status {resp.status_code}: {resp.text}")
                except Exception as e:
                    logger.exception("HTTP call to send-push-via-bot failed, falling back to direct logic")
                    # Fallback-вызов логики напрямую в Python
                    try:
                        from django.contrib.auth import get_user_model
                        User = get_user_model()
                        manager = User.objects.get(telegram_id=str(chat_id), is_active=True)
                        is_allowed = (
                            manager.is_superuser or manager.role in ('admin', 'content_manager')
                        )
                        if is_allowed:
                            from apps.notifications.models import UserDevice, PushCampaign
                            from apps.notifications.tasks import send_bulk_push_notification
                            user_ids = list(UserDevice.objects.values_list('user_id', flat=True).distinct())
                            campaign = PushCampaign.objects.create(
                                title=title,
                                body=body,
                                category=category,
                                segment='all',
                                total_users=len(user_ids)
                            )
                            send_bulk_push_notification.delay(
                                user_ids=user_ids,
                                title=title,
                                body=body,
                                data={'campaign_id': str(campaign.pk)},
                                category=category,
                                campaign_id=campaign.pk
                            )
                            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Рассылка запущена (fallback)!'}, token)
                            _tg_post('editMessageText', {
                                'chat_id': chat_id,
                                'message_id': message_id,
                                'text': f"✅ <b>Рассылка успешно запущена (fallback)!</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(body)}",
                                'parse_mode': 'HTML',
                            }, token)
                            _tg_post('sendMessage', {
                                'chat_id': chat_id,
                                'text': 'Вы можете создать новую рассылку в любое время.',
                                'reply_markup': _get_manager_keyboard()
                            }, token)
                        else:
                            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Недостаточно прав.'}, token)
                    except Exception as direct_err:
                        logger.exception("Direct fallback execution also failed")
                        _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Ошибка при отправке.'}, token)

                return JsonResponse({'ok': True})

        # Обработка выбора категории push-рассылки
        elif parts[0] == 'push_category':
            category = parts[1]  # '', 'events', 'promotions', 'closed_events'
            cache_key = f"tg_fsm:{chat_id}"
            state_data = cache.get(cache_key)

            if not state_data or state_data.get('state') != 'waiting_for_category':
                _tg_post('answerCallbackQuery', {
                    'callback_query_id': callback_id,
                    'text': 'Время ожидания истекло.',
                    'show_alert': True,
                }, token)
                return JsonResponse({'ok': True})

            category_labels = {
                '': 'Сервисное',
                'events': 'Мероприятия',
                'promotions': 'Акции',
                'closed_events': 'Закрытые мероприятия',
            }
            category_label = category_labels.get(category, category)

            title = state_data['data']['title']
            body = state_data['data']['body']
            cache.set(cache_key, {
                'state': 'waiting_for_confirmation',
                'data': {'title': title, 'body': body, 'category': category}
            }, timeout=600)

            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': f'Категория: {category_label}'}, token)
            _tg_post('editMessageText', {
                'chat_id': chat_id,
                'message_id': message_id,
                'text': f'Выбрана категория: <b>{category_label}</b>',
                'parse_mode': 'HTML',
            }, token)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': (
                    f'<b>Предпросмотр рассылки:</b>\n\n'
                    f'<b>Заголовок:</b> {html.escape(title)}\n'
                    f'<b>Текст:</b> {html.escape(body)}\n'
                    f'<b>Категория:</b> {category_label}\n\n'
                    f'Подтверждаете отправку всем клиентам?'
                ),
                'parse_mode': 'HTML',
                'reply_markup': {
                    'inline_keyboard': [[
                        {'text': '✅ Подтвердить', 'callback_data': 'bulk_push:confirm'},
                        {'text': '❌ Отменить', 'callback_data': 'bulk_push:cancel'}
                    ]]
                }
            }, token)
            return JsonResponse({'ok': True})

        # Обработка подтверждения/отмены бронирования
        elif parts[0] in ('confirm', 'cancel'):
            action = parts[0]
            booking_id_str = parts[1]
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

        else:
            return JsonResponse({'ok': True})

    def handle_message(self, request, message, token):
        chat_id = message.get('chat', {}).get('id')
        text = message.get('text') or ''
        text = text.strip()

        if not chat_id:
            return JsonResponse({'ok': True})

        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            manager = User.objects.get(telegram_id=str(chat_id), is_active=True)
        except User.DoesNotExist:
            manager = None

        is_authorized = manager is not None and (
            manager.is_superuser or manager.role in ('admin', 'content_manager')
        )

        # Команда /start
        if text.startswith('/start'):
            if is_authorized:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Приветствуем! Вы успешно авторизованы как менеджер.\n\nВы можете запустить рассылку push-уведомлений, нажав на кнопку ниже.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
            else:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': f'Приветствуем!\n\nВаш Telegram ID: <code>{chat_id}</code>\n\nУ вас пока нет прав на управление. Скопируйте этот ID и передайте администратору для привязки в панели управления Django.',
                    'parse_mode': 'HTML',
                }, token)
            return JsonResponse({'ok': True})

        # Все остальные действия требуют авторизации
        if not is_authorized:
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'У вас нет прав для выполнения этой операции.'
            }, token)
            return JsonResponse({'ok': True})

        cache_key = f"tg_fsm:{chat_id}"

        # Обработка отмены (команда /cancel или кнопка "❌ Отмена")
        if text in ('/cancel', '❌ Отмена'):
            cache.delete(cache_key)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Действие отменено.',
                'reply_markup': _get_manager_keyboard()
            }, token)
            return JsonResponse({'ok': True})

        state_data = cache.get(cache_key) or {}
        state = state_data.get('state')

        # Запуск создания пуша (/sendpush или кнопка "📢 Отправить пуш")
        if text in ('/sendpush', '📢 Отправить пуш'):
            cache.set(cache_key, {'state': 'waiting_for_title', 'data': {}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 1 из 3: Введите <b>заголовок</b> для push-уведомления:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        # --- Состояния создания Push ---
        if state == 'waiting_for_title':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Заголовок не может быть пустым. Пожалуйста, введите заголовок:'
                }, token)
                return JsonResponse({'ok': True})

            cache.set(cache_key, {'state': 'waiting_for_body', 'data': {'title': text}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': f'Заголовок: "<b>{html.escape(text)}</b>"\n\nШаг 2 из 3: Введите <b>текст</b> (описание) для push-уведомления:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_body':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Текст пуша не может быть пустым. Пожалуйста, введите текст:'
                }, token)
                return JsonResponse({'ok': True})

            title = state_data['data']['title']
            cache.set(cache_key, {'state': 'waiting_for_category', 'data': {'title': title, 'body': text}}, timeout=600)

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 3 из 3: Выберите <b>категорию</b> рассылки:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'inline_keyboard': [
                        [{'text': '📢 Сервисное (без ограничений)', 'callback_data': 'push_category:'}],
                        [{'text': '🎪 Мероприятия', 'callback_data': 'push_category:events'}],
                        [{'text': '🎁 Акции', 'callback_data': 'push_category:promotions'}],
                        [{'text': '🔒 Закрытые мероприятия', 'callback_data': 'push_category:closed_events'}],
                    ]
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_category':
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Пожалуйста, выберите категорию с помощью кнопок под сообщением или нажмите «❌ Отмена»:'
            }, token)
            return JsonResponse({'ok': True})

        # Неизвестный ввод вне состояний
        else:
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Неизвестная команда. Воспользуйтесь меню или введите /start.'
            }, token)

        return JsonResponse({'ok': True})


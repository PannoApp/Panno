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
            [{'text': '📰 Создать новость'}, {'text': '📅 Создать мероприятие'}]
        ],
        'resize_keyboard': True,
    }


def _download_telegram_photo(file_id, token):
    """
    Downloads a photo from Telegram by file_id.
    Returns (filename, ContentFile) or None.
    """
    import os
    import requests
    from django.core.files.base import ContentFile

    file_info_url = f"https://api.telegram.org/bot{token}/getFile"
    try:
        resp = requests.post(file_info_url, json={'file_id': file_id}, timeout=10)
        if not resp.ok:
            logger.error("Telegram getFile error: status=%s body=%s", resp.status_code, resp.text)
            return None
        file_path = resp.json().get('result', {}).get('file_path')
        if not file_path:
            logger.error("Telegram getFile response does not contain file_path: %s", resp.text)
            return None

        file_download_url = f"https://api.telegram.org/file/bot{token}/{file_path}"
        img_resp = requests.get(file_download_url, timeout=15)
        if img_resp.ok:
            ext = os.path.splitext(file_path)[1] or '.jpg'
            filename = f"{file_id}{ext}"
            return filename, ContentFile(img_resp.content)
        else:
            logger.error("Failed to download file from Telegram: status=%s", img_resp.status_code)
    except Exception:
        logger.exception("Error downloading photo from Telegram")
    return None


@method_decorator(csrf_exempt, name='dispatch')
class TelegramWebhookView(View):
    """
    Принимает callback_query от Telegram при нажатии inline-кнопок
    «Подтвердить» / «Отменить» в уведомлениях о бронировании,
    а также обрабатывает текстовые сообщения и команды для рассылки push-уведомлений,
    создания новостей и мероприятий контент-менеджерами.
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
        if len(parts) != 2 or parts[0] not in ('confirm', 'cancel', 'bulk_push', 'news', 'event', 'event_format'):
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
                    'body': body
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
                                category='promotions',
                                segment='all',
                                total_users=len(user_ids)
                            )
                            send_bulk_push_notification.delay(
                                user_ids=user_ids,
                                title=title,
                                body=body,
                                data={'campaign_id': str(campaign.pk)},
                                category='promotions',
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

        # Обработка подтверждения/отмены создания новости
        elif parts[0] == 'news':
            action = parts[1]
            cache_key = f"tg_fsm:{chat_id}"
            state_data = cache.get(cache_key)

            if not state_data or state_data.get('state') != 'waiting_for_news_confirmation':
                _tg_post('answerCallbackQuery', {
                    'callback_query_id': callback_id,
                    'text': 'Время ожидания истекло или новость уже создана.',
                    'show_alert': True,
                }, token)
                return JsonResponse({'ok': True})

            if action == 'cancel':
                cache.delete(cache_key)
                _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Создание новости отменено.'}, token)
                _tg_post('editMessageText', {
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'text': '❌ Создание новости отменено.',
                }, token)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Вы можете начать заново в любое время.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
                return JsonResponse({'ok': True})

            elif action == 'confirm':
                title = state_data['data']['title']
                content = state_data['data']['content']
                file_id = state_data['data'].get('file_id')
                cache.delete(cache_key)

                from apps.events.models import News
                news = News(title=title, content=content)

                if file_id:
                    downloaded = _download_telegram_photo(file_id, token)
                    if downloaded:
                        filename, content_file = downloaded
                        news.image.save(filename, content_file, save=False)
                    else:
                        _tg_post('answerCallbackQuery', {
                            'callback_query_id': callback_id,
                            'text': 'Ошибка скачивания фото. Создана новость без картинки.',
                            'show_alert': True,
                        }, token)

                news.save()

                _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Новость успешно создана!'}, token)
                _tg_post('editMessageText', {
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'text': f"✅ <b>Новость успешно опубликована!</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(content)}",
                    'parse_mode': 'HTML',
                }, token)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Вы можете создать еще новости или мероприятия в любое время.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
                return JsonResponse({'ok': True})

        # Обработка выбора формата мероприятия
        elif parts[0] == 'event_format':
            action = parts[1]  # 'open' or 'closed'
            cache_key = f"tg_fsm:{chat_id}"
            state_data = cache.get(cache_key)

            if not state_data or state_data.get('state') != 'waiting_for_event_format':
                _tg_post('answerCallbackQuery', {
                    'callback_query_id': callback_id,
                    'text': 'Время ожидания истекло или неверное состояние.',
                    'show_alert': True,
                }, token)
                return JsonResponse({'ok': True})

            state_data['state'] = 'waiting_for_event_price'
            state_data['data']['format'] = action
            cache.set(cache_key, state_data, timeout=600)

            format_label = 'Открытое' if action == 'open' else 'Закрытое'
            _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': f'Формат: {format_label}'}, token)
            _tg_post('editMessageText', {
                'chat_id': chat_id,
                'message_id': message_id,
                'text': f"Выбран формат: <b>{format_label}</b>",
                'parse_mode': 'HTML',
            }, token)

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 5 из 7: Укажите <b>цену входа</b> (в тенге) или нажмите кнопку «🆓 Вход свободный»:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '🆓 Вход свободный'}], [{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        # Обработка подтверждения/отмены создания мероприятия
        elif parts[0] == 'event':
            action = parts[1]
            cache_key = f"tg_fsm:{chat_id}"
            state_data = cache.get(cache_key)

            if not state_data or state_data.get('state') != 'waiting_for_event_confirmation':
                _tg_post('answerCallbackQuery', {
                    'callback_query_id': callback_id,
                    'text': 'Время ожидания истекло или мероприятие уже создано.',
                    'show_alert': True,
                }, token)
                return JsonResponse({'ok': True})

            if action == 'cancel':
                cache.delete(cache_key)
                _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Создание мероприятия отменено.'}, token)
                _tg_post('editMessageText', {
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'text': '❌ Создание мероприятия отменено.',
                }, token)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Вы можете начать заново в любое время.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
                return JsonResponse({'ok': True})

            elif action == 'confirm':
                title = state_data['data']['title']
                description = state_data['data']['description']
                datetime_str = state_data['data']['datetime']
                format_val = state_data['data']['format']
                price_val = state_data['data']['price']
                file_id = state_data['data'].get('file_id')
                cache.delete(cache_key)

                from datetime import datetime
                from django.utils import timezone
                import pytz
                from decimal import Decimal
                from apps.events.models import Event

                tz = pytz.timezone('Asia/Almaty')
                naive_dt = datetime.strptime(datetime_str, '%d.%m.%Y %H:%M')
                dt_obj = timezone.make_aware(naive_dt, timezone=tz)

                price = Decimal(price_val) if price_val is not None else None

                event = Event(
                    title=title,
                    description=description,
                    date_time=dt_obj,
                    format=format_val,
                    price=price
                )

                if file_id:
                    downloaded = _download_telegram_photo(file_id, token)
                    if downloaded:
                        filename, content_file = downloaded
                        event.image.save(filename, content_file, save=False)
                    else:
                        _tg_post('answerCallbackQuery', {
                            'callback_query_id': callback_id,
                            'text': 'Ошибка скачивания фото. Мероприятие не создано.',
                            'show_alert': True,
                        }, token)
                        _tg_post('editMessageText', {
                            'chat_id': chat_id,
                            'message_id': message_id,
                            'text': '❌ Ошибка при скачивании обложки мероприятия с серверов Telegram. Мероприятие не было создано.',
                        }, token)
                        _tg_post('sendMessage', {
                            'chat_id': chat_id,
                            'text': 'Пожалуйста, попробуйте создать мероприятие еще раз.',
                            'reply_markup': _get_manager_keyboard()
                        }, token)
                        return JsonResponse({'ok': True})
                else:
                    _tg_post('answerCallbackQuery', {
                        'callback_query_id': callback_id,
                        'text': 'Отсутствует обложка. Мероприятие не создано.',
                        'show_alert': True,
                    }, token)
                    _tg_post('editMessageText', {
                        'chat_id': chat_id,
                        'message_id': message_id,
                        'text': '❌ Ошибка: отсутствует обложка мероприятия. Мероприятие не было создано.',
                    }, token)
                    _tg_post('sendMessage', {
                        'chat_id': chat_id,
                        'text': 'Пожалуйста, попробуйте создать мероприятие еще раз.',
                        'reply_markup': _get_manager_keyboard()
                    }, token)
                    return JsonResponse({'ok': True})

                event.save()

                format_label = 'Открытое' if format_val == 'open' else 'Закрытое'
                price_label = f"{price} KZT" if price is not None else 'Вход свободный'
                _tg_post('answerCallbackQuery', {'callback_query_id': callback_id, 'text': 'Мероприятие успешно создано!'}, token)
                _tg_post('editMessageText', {
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'text': f"✅ <b>Мероприятие успешно опубликовано!</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Дата и время:</b> {datetime_str}\n<b>Формат:</b> {format_label}\n<b>Вход:</b> {price_label}",
                    'parse_mode': 'HTML',
                }, token)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Создание мероприятия завершено.',
                    'reply_markup': _get_manager_keyboard()
                }, token)
                return JsonResponse({'ok': True})

        # Обработка подтверждения/отмены бронирования
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
                    'text': 'Приветствуем! Вы успешно авторизованы как менеджер.\n\nВы можете запустить рассылку push-уведомлений, создавать новости и мероприятия, нажав на соответствующие кнопки ниже.',
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
                'text': 'Шаг 1 из 2: Введите <b>заголовок</b> для push-уведомления:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        # Запуск создания новости (/createnews или кнопка "📰 Создать новость")
        if text in ('/createnews', '📰 Создать новость'):
            cache.set(cache_key, {'state': 'waiting_for_news_title', 'data': {}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 1 из 3: Введите <b>заголовок</b> для новости:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        # Запуск создания мероприятия (/createevent или кнопка "📅 Создать мероприятие")
        if text in ('/createevent', '📅 Создать мероприятие'):
            cache.set(cache_key, {'state': 'waiting_for_event_title', 'data': {}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 1 из 7: Введите <b>заголовок</b> для мероприятия:',
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
                'text': f'Заголовок: "<b>{html.escape(text)}</b>"\n\nШаг 2 из 2: Введите <b>текст</b> (описание) для push-уведомления:',
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
            cache.set(cache_key, {'state': 'waiting_for_confirmation', 'data': {'title': title, 'body': text}}, timeout=600)

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': f'<b>Предпросмотр рассылки:</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(text)}\n\nПодтверждаете отправку всем клиентам?',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'inline_keyboard': [[
                        {'text': '✅ Подтвердить', 'callback_data': 'bulk_push:confirm'},
                        {'text': '❌ Отменить', 'callback_data': 'bulk_push:cancel'}
                    ]]
                }
            }, token)
            return JsonResponse({'ok': True})

        # --- Состояния создания Новости ---
        elif state == 'waiting_for_news_title':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Заголовок новости не может быть пустым. Пожалуйста, введите заголовок:'
                }, token)
                return JsonResponse({'ok': True})

            cache.set(cache_key, {'state': 'waiting_for_news_content', 'data': {'title': text}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': f'Заголовок: "<b>{html.escape(text)}</b>"\n\nШаг 2 из 3: Введите <b>текст</b> новости:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_news_content':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Текст новости не может быть пустым. Пожалуйста, введите текст:'
                }, token)
                return JsonResponse({'ok': True})

            title = state_data['data']['title']
            cache.set(cache_key, {'state': 'waiting_for_news_image', 'data': {'title': title, 'content': text}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': (
                    "⚠️ <b>Важно:</b> Загруженное фото новости в будущем можно будет изменить или удалить только через панель управления (админку) Django.\n\n"
                    "Пожалуйста, перед отправкой подготовьте изображение с соотношением сторон <b>16:9</b> (например, 1920x1080) для идеального отображения в мобильном приложении.\n\n"
                    "Шаг 3 из 3: Отправьте изображение новости (или нажмите кнопку «⏭ Пропустить»):"
                ),
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '⏭ Пропустить'}], [{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_news_image':
            photo = message.get('photo')
            title = state_data['data']['title']
            content = state_data['data']['content']

            if photo:
                file_id = photo[-1]['file_id']
                cache.set(cache_key, {'state': 'waiting_for_news_confirmation', 'data': {'title': title, 'content': content, 'file_id': file_id}}, timeout=600)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': f"<b>Предпросмотр новости:</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(content)}\n<b>Фото:</b> Прикреплено 16:9\n\nОпубликовать новость?",
                    'parse_mode': 'HTML',
                    'reply_markup': {
                        'inline_keyboard': [[
                            {'text': '✅ Опубликовать', 'callback_data': 'news:confirm'},
                            {'text': '❌ Отменить', 'callback_data': 'news:cancel'}
                        ]]
                    }
                }, token)
                return JsonResponse({'ok': True})

            elif text in ('⏭ Пропустить', '/skip'):
                cache.set(cache_key, {'state': 'waiting_for_news_confirmation', 'data': {'title': title, 'content': content, 'file_id': None}}, timeout=600)
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': f"<b>Предпросмотр новости:</b>\n\n<b>Заголовок:</b> {html.escape(title)}\n<b>Текст:</b> {html.escape(content)}\n<b>Фото:</b> Отсутствует\n\nОпубликовать новость?",
                    'parse_mode': 'HTML',
                    'reply_markup': {
                        'inline_keyboard': [[
                            {'text': '✅ Опубликовать', 'callback_data': 'news:confirm'},
                            {'text': '❌ Отменить', 'callback_data': 'news:cancel'}
                        ]]
                    }
                }, token)
                return JsonResponse({'ok': True})

            else:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Пожалуйста, отправьте изображение новости (фото) или нажмите «⏭ Пропустить»:'
                }, token)
                return JsonResponse({'ok': True})

        # --- Состояния создания Мероприятия ---
        elif state == 'waiting_for_event_title':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Название мероприятия не может быть пустым. Пожалуйста, введите название:'
                }, token)
                return JsonResponse({'ok': True})

            cache.set(cache_key, {'state': 'waiting_for_event_description', 'data': {'title': text}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': f'Название: "<b>{html.escape(text)}</b>"\n\nШаг 2 из 7: Введите <b>описание</b> мероприятия:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_event_description':
            if not text:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Описание мероприятия не может быть пустым. Пожалуйста, введите описание:'
                }, token)
                return JsonResponse({'ok': True})

            title = state_data['data']['title']
            cache.set(cache_key, {'state': 'waiting_for_event_datetime', 'data': {'title': title, 'description': text}}, timeout=600)
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 3 из 7: Введите <b>дату и время</b> проведения мероприятия в формате `ДД.ММ.ГГГГ ЧЧ:ММ` (например, `25.05.2026 19:00`):',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_event_datetime':
            from datetime import datetime
            from django.utils import timezone
            import pytz

            try:
                naive_dt = datetime.strptime(text, '%d.%m.%Y %H:%M')
                tz = pytz.timezone('Asia/Almaty')
                timezone.make_aware(naive_dt, timezone=tz)
            except ValueError:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': '❌ Неверный формат даты и времени. Пожалуйста, введите дату в формате `ДД.ММ.ГГГГ ЧЧ:ММ` (например, `25.05.2026 19:00`):',
                    'parse_mode': 'HTML'
                }, token)
                return JsonResponse({'ok': True})

            title = state_data['data']['title']
            description = state_data['data']['description']
            cache.set(cache_key, {'state': 'waiting_for_event_format', 'data': {'title': title, 'description': description, 'datetime': text}}, timeout=600)

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Шаг 4 из 7: Выберите <b>формат</b> мероприятия:',
                'parse_mode': 'HTML',
                'reply_markup': {
                    'inline_keyboard': [[
                        {'text': '🔓 Открытое', 'callback_data': 'event_format:open'},
                        {'text': '🔒 Закрытое', 'callback_data': 'event_format:closed'}
                    ]]
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_event_format':
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Пожалуйста, выберите формат мероприятия с помощью кнопок под сообщением или нажмите «❌ Отмена» для отмены:'
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_event_price':
            from decimal import Decimal, InvalidOperation

            title = state_data['data']['title']
            description = state_data['data']['description']
            datetime_str = state_data['data']['datetime']
            format_val = state_data['data']['format']

            price = None
            if text not in ('🆓 Вход свободный', '/skip'):
                try:
                    price_str = text.replace(',', '.')
                    price = Decimal(price_str)
                    if price < 0:
                        raise InvalidOperation()
                except (InvalidOperation, ValueError):
                    _tg_post('sendMessage', {
                        'chat_id': chat_id,
                        'text': '❌ Некорректная цена. Пожалуйста, введите положительное число или нажмите «🆓 Вход свободный»:'
                    }, token)
                    return JsonResponse({'ok': True})

            # Сохраняем цену как строку или None для кэша
            price_val = str(price) if price is not None else None
            cache.set(cache_key, {
                'state': 'waiting_for_event_image',
                'data': {
                    'title': title,
                    'description': description,
                    'datetime': datetime_str,
                    'format': format_val,
                    'price': price_val
                }
            }, timeout=600)

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': (
                    "⚠️ <b>Важно:</b> Обложка является обязательной для мероприятия. Изменить или удалить её позже можно будет только через панель управления (админку) Django.\n\n"
                    "Пожалуйста, перед отправкой подготовьте изображение с соотношением сторон <b>16:9</b> (например, 1920x1080) для идеального отображения в мобильном приложении.\n\n"
                    "Шаг 6 из 7: Отправьте изображение обложки (фото):"
                ),
                'parse_mode': 'HTML',
                'reply_markup': {
                    'keyboard': [[{'text': '❌ Отмена'}]],
                    'resize_keyboard': True,
                }
            }, token)
            return JsonResponse({'ok': True})

        elif state == 'waiting_for_event_image':
            photo = message.get('photo')
            if not photo:
                _tg_post('sendMessage', {
                    'chat_id': chat_id,
                    'text': 'Пожалуйста, отправьте изображение обложки (фото). Обложка обязательна для мероприятия:'
                }, token)
                return JsonResponse({'ok': True})

            file_id = photo[-1]['file_id']
            title = state_data['data']['title']
            description = state_data['data']['description']
            datetime_str = state_data['data']['datetime']
            format_val = state_data['data']['format']
            price_val = state_data['data']['price']

            cache.set(cache_key, {
                'state': 'waiting_for_event_confirmation',
                'data': {
                    'title': title,
                    'description': description,
                    'datetime': datetime_str,
                    'format': format_val,
                    'price': price_val,
                    'file_id': file_id
                }
            }, timeout=600)

            format_label = 'Открытое' if format_val == 'open' else 'Закрытое'
            price_label = f"{price_val} KZT" if price_val is not None else 'Вход свободный'

            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': (
                    f"<b>Предпросмотр мероприятия:</b>\n\n"
                    f"<b>Заголовок:</b> {html.escape(title)}\n"
                    f"<b>Описание:</b> {html.escape(description)}\n"
                    f"<b>Дата и время:</b> {datetime_str}\n"
                    f"<b>Формат:</b> {format_label}\n"
                    f"<b>Цена входа:</b> {price_label}\n"
                    f"<b>Обложка:</b> Прикреплена 16:9\n\n"
                    f"Опубликовать мероприятие?"
                ),
                'parse_mode': 'HTML',
                'reply_markup': {
                    'inline_keyboard': [[
                        {'text': '✅ Создать', 'callback_data': 'event:confirm'},
                        {'text': '❌ Отменить', 'callback_data': 'event:cancel'}
                    ]]
                }
            }, token)
            return JsonResponse({'ok': True})

        # Неизвестный ввод вне состояний
        else:
            _tg_post('sendMessage', {
                'chat_id': chat_id,
                'text': 'Неизвестная команда. Воспользуйтесь меню или введите /start.'
            }, token)

        return JsonResponse({'ok': True})


from django.utils import timezone
from datetime import timedelta
from rest_framework import status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from utils.permissions import IsContentManager
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse
from .models import UserDevice, PushCampaign
from django.conf import settings
from .serializers import UserDeviceSerializer, BulkPushSerializer, SendPushViaBotSerializer


@extend_schema(tags=['Notifications'])
class RegisterDeviceView(views.APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary='Зарегистрировать или обновить FCM-токен устройства',
        description=(
            'Регистрирует FCM-токен мобильного устройства для отправки push-уведомлений.\n\n'
            'Если токен уже существует в базе — он перепривязывается к текущему пользователю '
            '(полезно при смене аккаунта на одном устройстве).\n\n'
            'Вызывать при каждом входе в приложение и при обновлении FCM-токена Firebase.'
        ),
        request=UserDeviceSerializer,
        responses={
            201: OpenApiResponse(
                description='Устройство успешно зарегистрировано',
                examples=[
                    OpenApiExample(
                        'Создано',
                        value={'message': 'Устройство успешно зарегистрировано.'},
                    )
                ],
            ),
            200: OpenApiResponse(
                description='Токен уже существует, перепривязан к текущему пользователю',
                examples=[
                    OpenApiExample(
                        'Обновлено',
                        value={'message': 'Токен устройства обновлен (перепривязан).'},
                    )
                ],
            ),
            400: OpenApiResponse(
                description='Ошибка валидации — токен не передан или пустой',
                examples=[
                    OpenApiExample(
                        'Ошибка',
                        value={'fcm_token': ['Обязательное поле.']},
                    )
                ],
            ),
            401: OpenApiResponse(description='Токен не передан или недействителен'),
        },
        examples=[
            OpenApiExample(
                'Регистрация устройства',
                value={'fcm_token': 'dGhpcyBpcyBhIHNhbXBsZSBmY20gdG9rZW4...'},
                request_only=True,
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = UserDeviceSerializer(data=request.data)

        if serializer.is_valid():
            fcm_token = serializer.validated_data['fcm_token']

            device, created = UserDevice.objects.update_or_create(
                fcm_token=fcm_token,
                defaults={'user': request.user}
            )

            if created:
                return Response(
                    {"message": "Устройство успешно зарегистрировано."},
                    status=status.HTTP_201_CREATED
                )

            return Response(
                {"message": "Токен устройства обновлен (перепривязан)."},
                status=status.HTTP_200_OK
            )

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(
    tags=['Notifications'],
    summary='Массовая рассылка push-уведомлений',
    description=(
        'Отправляет push выбранному сегменту пользователей. '
        'Доступен только персоналу (`is_staff=True`).\n\n'
        '**Сегменты:**\n'
        '- `all` — все пользователи с FCM-устройствами\n'
        '- `last_visit_days` — посещали ресторан в последние N дней (по бронированиям со статусом `completed`)\n'
        '- `participated_in_event` — участники конкретного мероприятия\n'
        '- `registered_after` — зарегистрированные после указанной даты'
    ),
    request=BulkPushSerializer,
    responses={
        202: OpenApiResponse(description='Рассылка поставлена в очередь'),
        400: OpenApiResponse(description='Ошибка валидации'),
        403: OpenApiResponse(description='Нет прав (требуется is_staff)'),
    },
)
class BulkPushView(views.APIView):
    permission_classes = [IsContentManager]

    def post(self, request, *args, **kwargs):
        serializer = BulkPushSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        segment = data['segment']

        from django.contrib.auth import get_user_model
        User = get_user_model()

        if segment == 'all':
            user_ids = list(
                UserDevice.objects.values_list('user_id', flat=True).distinct()
            )
        elif segment == 'last_visit_days':
            days = data.get('last_visit_days', 30)
            since = timezone.now() - timedelta(days=days)
            from apps.bookings.models import TableBooking
            raw_ids = list(
                TableBooking.objects.filter(
                    status='completed',
                    updated_at__gte=since,
                    user__isnull=False,
                ).values_list('user_id', flat=True).distinct()
            )
            # Оставляем только тех, у кого есть хотя бы одно FCM-устройство,
            # чтобы не создавать лишние Celery-задачи вхолостую.
            user_ids = list(
                UserDevice.objects.filter(user_id__in=raw_ids)
                .values_list('user_id', flat=True)
                .distinct()
            )
        elif segment == 'participated_in_event':
            event_id = data.get('event_id')
            if not event_id:
                return Response({'event_id': ['Обязательно для сегмента participated_in_event.']}, status=400)
            from apps.events.models import EventReservation
            raw_ids = list(
                EventReservation.objects.filter(event_id=event_id).values_list('user_id', flat=True).distinct()
            )
            # Оставляем только тех, у кого есть хотя бы одно FCM-устройство.
            user_ids = list(
                UserDevice.objects.filter(user_id__in=raw_ids)
                .values_list('user_id', flat=True)
                .distinct()
            )
        elif segment == 'registered_after':
            date = data.get('registered_after')
            if not date:
                return Response({'registered_after': ['Обязательно для сегмента registered_after.']}, status=400)
            raw_ids = list(
                User.objects.filter(date_joined__date__gte=date).values_list('id', flat=True)
            )
            # Оставляем только тех, у кого есть хотя бы одно FCM-устройство.
            user_ids = list(
                UserDevice.objects.filter(user_id__in=raw_ids)
                .values_list('user_id', flat=True)
                .distinct()
            )
        else:
            user_ids = []

        campaign = PushCampaign.objects.create(
            title=data['title'],
            body=data['body'],
            category=data.get('category') or '',
            segment=segment,
            total_users=len(user_ids),
        )

        from .tasks import send_bulk_push_notification
        send_bulk_push_notification.delay(
            user_ids=user_ids,
            title=data['title'],
            body=data['body'],
            data=data.get('data', {}),
            category=data.get('category'),
            campaign_id=campaign.pk,
        )

        return Response(
            {'queued': len(user_ids), 'segment': segment},
            status=status.HTTP_202_ACCEPTED,
        )


class SendPushViaBotView(views.APIView):
    permission_classes = []  # Public endpoint, validation relies on secret token and manager role

    @extend_schema(
        tags=['Notifications'],
        summary='Рассылка push-уведомления через Telegram-бот',
        description='Принимает запрос от Telegram-бота для массовой рассылки push-уведомлений всем зарегистрированным устройствам.',
        request=SendPushViaBotSerializer,
        responses={
            202: OpenApiResponse(description='Рассылка успешно поставлена в очередь'),
            400: OpenApiResponse(description='Ошибка валидации данных'),
            403: OpenApiResponse(description='Доступ запрещен (неверный токен вебхука или менеджер не найден/не имеет прав)'),
        }
    )
    def post(self, request, *args, **kwargs):
        secret = getattr(settings, 'TELEGRAM_WEBHOOK_SECRET', '')
        if secret and request.headers.get('X-Telegram-Bot-Api-Secret-Token', '') != secret:
            return Response({'error': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)

        serializer = SendPushViaBotSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        manager_telegram_id = serializer.validated_data['manager_telegram_id']
        title = serializer.validated_data['title']
        body = serializer.validated_data['body']

        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            manager = User.objects.get(telegram_id=manager_telegram_id)
        except User.DoesNotExist:
            return Response({'error': 'Manager not found'}, status=status.HTTP_403_FORBIDDEN)

        # Разрешено только активным пользователям (is_active=True)
        # с ролью admin или content_manager (или is_superuser)
        is_allowed = (
            manager.is_active and
            (manager.is_superuser or manager.role in ('admin', 'content_manager'))
        )
        if not is_allowed:
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        user_ids = list(
            UserDevice.objects.values_list('user_id', flat=True).distinct()
        )

        campaign = PushCampaign.objects.create(
            title=title,
            body=body,
            category='promotions',
            segment='all',
            total_users=len(user_ids),
        )

        from .tasks import send_bulk_push_notification
        send_bulk_push_notification.delay(
            user_ids=user_ids,
            title=title,
            body=body,
            data={'campaign_id': str(campaign.pk)},
            category='promotions',
            campaign_id=campaign.pk,
        )

        return Response(
            {'queued': len(user_ids), 'campaign_id': campaign.pk},
            status=status.HTTP_202_ACCEPTED
        )


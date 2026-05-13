from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import ScopedRateThrottle

from .throttles import PhoneSMSThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse

from .serializers import RequestSMSSerializer, VerifySMSSerializer, UserProfileSerializer
from .services import SMSService

User = get_user_model()


_error_401 = OpenApiResponse(description='Токен не передан или недействителен')

_sms_request_400 = OpenApiResponse(
    description='Ошибка валидации — неверный формат номера телефона',
    examples=[
        OpenApiExample(
            'Неверный формат',
            value={'phone': ["Номер телефона должен быть в формате: '+77001234567'."]},
        )
    ],
)


@extend_schema(tags=['Auth'])
class RequestSMSView(APIView):
    permission_classes = [AllowAny]
    # Два уровня защиты: по IP (ScopedRateThrottle) + по номеру телефона (PhoneSMSThrottle)
    throttle_classes = [ScopedRateThrottle, PhoneSMSThrottle]
    throttle_scope = 'sms_request'

    @extend_schema(
        summary='Запрос SMS с кодом подтверждения',
        description=(
            'Отправляет на указанный номер телефона 4-значный OTP-код через SMS.\n\n'
            'Код действителен **3 минуты** и хранится в Redis.\n\n'
            '**Лимит:** 3 запроса в минуту с одного IP-адреса '
            'и 5 запросов за 10 минут на один номер телефона.'
        ),
        request=RequestSMSSerializer,
        responses={
            200: OpenApiResponse(
                description='SMS успешно отправлен',
                examples=[
                    OpenApiExample('Успех', value={'message': 'SMS код отправлен.'})
                ],
            ),
            400: _sms_request_400,
            429: OpenApiResponse(
                description='Превышен лимит запросов (3/мин с одного IP или 5/10мин на номер)'
            ),
            500: OpenApiResponse(
                description='Ошибка сервера при отправке SMS',
                examples=[
                    OpenApiExample('Ошибка', value={'error': 'Ошибка при отправке SMS.'}),
                ],
            ),
        },
        examples=[
            OpenApiExample(
                'Запрос',
                value={'phone': '+77001234567'},
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = RequestSMSSerializer(data=request.data)
        if serializer.is_valid():
            phone = serializer.validated_data['phone']
            if SMSService.send_sms(phone):
                return Response({'message': 'SMS код отправлен.'})
            return Response(
                {'error': 'Ошибка при отправке SMS.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=['Auth'])
class VerifySMSView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sms_verify'

    @extend_schema(
        summary='Подтверждение SMS-кода и получение JWT-токенов',
        description=(
            'Проверяет OTP-код из SMS. При успехе возвращает пару JWT-токенов.\n\n'
            'Если пользователь с таким номером ещё не существует — он создаётся автоматически.\n\n'
            '**Лимит:** 5 попыток в минуту с одного IP-адреса.\n\n'
            'Полученный `access` токен передавайте в заголовке: `Authorization: Bearer <access>`'
        ),
        request=VerifySMSSerializer,
        responses={
            200: OpenApiResponse(
                description='Авторизация успешна',
                examples=[
                    OpenApiExample(
                        'Успех',
                        value={
                            'message': 'Успешная авторизация',
                            'is_new_user': False,
                            'user_id': 42,
                            'access': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<payload>.<signature>',
                            'refresh': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<payload>.<signature>',
                        },
                    )
                ],
            ),
            400: OpenApiResponse(
                description='Неверный или просроченный код, либо ошибка валидации',
                examples=[
                    OpenApiExample(
                        'Неверный код',
                        value={'error': 'Неверный или просроченный код.'},
                    ),
                    OpenApiExample(
                        'Ошибка валидации',
                        value={'otp': ['Код должен состоять из 4 цифр.']},
                    ),
                ],
            ),
            429: OpenApiResponse(description='Превышен лимит попыток (5/мин с одного IP)'),
        },
        examples=[
            OpenApiExample(
                'Запрос',
                value={'phone': '+77001234567', 'otp': '4823'},
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = VerifySMSSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data['phone']
        otp = serializer.validated_data['otp']

        if not SMSService.verify_otp(phone, otp):
            return Response(
                {'error': 'Неверный или просроченный код.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user, created = User.objects.get_or_create(phone=phone)
        refresh = RefreshToken.for_user(user)

        return Response({
            'message': 'Успешная авторизация',
            'is_new_user': created,
            'user_id': user.id,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })


@extend_schema(tags=['Auth'])
class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'patch', 'head', 'options']

    @extend_schema(
        summary='Получить профиль текущего пользователя',
        description='Возвращает данные авторизованного пользователя: id, номер телефона, имя и фамилию.',
        responses={
            200: UserProfileSerializer,
            401: _error_401,
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        summary='Обновить профиль текущего пользователя',
        description=(
            'Частичное обновление профиля (PATCH). Можно передавать только изменяемые поля.\n\n'
            '`id` и `phone` — только для чтения, изменить их через этот эндпоинт нельзя.'
        ),
        request=UserProfileSerializer,
        responses={
            200: UserProfileSerializer,
            400: OpenApiResponse(description='Ошибка валидации'),
            401: _error_401,
        },
        examples=[
            OpenApiExample(
                'Обновление имени',
                value={'first_name': 'Алихан', 'last_name': 'Сейткали'},
                request_only=True,
            )
        ],
    )
    def patch(self, request, *args, **kwargs):
        return super().patch(request, *args, **kwargs)

    def get_object(self):
        return self.request.user

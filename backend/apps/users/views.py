from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics
from rest_framework.permissions import AllowAny, IsAuthenticated
import logging
import time

from .throttles import (
    PhoneSMSThrottle,
    SafeScopedRateThrottle,
    LoyaltyLoginPhoneThrottle,
    LoyaltyRegisterPhoneThrottle,
)
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.contrib.auth import get_user_model
from django.contrib.auth.models import update_last_login
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse

from .serializers import (
    RequestSMSSerializer,
    VerifySMSSerializer,
    LoyaltyLoginSerializer,
    LoyaltyRegisterSerializer,
    UserProfileSerializer,
    LogoutSerializer,
)
from .services import SMSService, RemarkedGuestService, apply_guest_data_to_user, maybe_push_guest_to_remarked

User = get_user_model()
logger = logging.getLogger(__name__)

# LoyaltyRegisterView: сколько раз пробовать get_info_by_phone сразу после
# успешного create_or_update, и пауза между попытками (см. комментарий в
# LoyaltyRegisterView.post).
REMARKED_POST_CREATE_LOOKUP_ATTEMPTS = 3
REMARKED_POST_CREATE_LOOKUP_DELAY = 0.7


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
    # Два уровня защиты: по IP (SafeScopedRateThrottle) + по номеру телефона (PhoneSMSThrottle)
    throttle_classes = [SafeScopedRateThrottle, PhoneSMSThrottle]
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
                {'error': 'Сервис временно недоступен. Попробуйте позже.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=['Auth'])
class VerifySMSView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [SafeScopedRateThrottle]
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
        if not user.is_active:
            return Response(
                {'error': 'Ваш аккаунт заблокирован.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Синхронный pull из Remarked с коротким таймаутом: пользователь должен
        # увидеть подтянутые данные сразу на этом ответе, а не через несколько
        # секунд после фонового Celery-таска. Сбой Remarked не должен ронять логин —
        # см. RemarkedGuestService.sync_on_login (там же fallback в Celery).
        RemarkedGuestService.sync_on_login(user)

        update_last_login(None, user)
        refresh = RefreshToken.for_user(user)

        return Response({
            'message': 'Успешная авторизация',
            'is_new_user': created,
            'user_id': user.id,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })


@extend_schema(tags=['Auth'])
class LoyaltyLoginView(APIView):
    """
    Вход по номеру телефона + номеру участника лояльности (ТЗ по входу, п.2) —
    альтернатива SMS-коду для гостей, у которых уже есть карта лояльности.

    Работает ТОЛЬКО для гостей, уже существующих в Remarked (есть карта,
    номер найден в поле `cards` ответа get_info_by_phone — источник
    подтверждён эмпирически 2026-08-15, см. docs/piligrim_improvements_plan.md).
    Регистрация новых гостей (без карты) через этот эндпоинт не
    выполняется — остаётся на SMS-OTP флоу (auth/request-sms/,
    auth/verify-sms/), пока не проверено, возвращает ли Remarked номер
    карты сразу синхронно при create_or_update.
    """
    permission_classes = [AllowAny]
    throttle_classes = [SafeScopedRateThrottle, LoyaltyLoginPhoneThrottle]
    throttle_scope = 'loyalty_login'

    @extend_schema(
        summary='Вход по номеру участника лояльности',
        description=(
            'Проверяет пару «номер телефона + номер участника» через Remarked '
            '(поле `cards` в ответе get_info_by_phone). При успехе возвращает '
            'пару JWT-токенов — как и /auth/verify-sms/.\n\n'
            'Работает только для гостей, уже имеющих карту лояльности в Remarked. '
            'Если гость не найден или номер участника не совпадает — 400/404.\n\n'
            '**Лимит:** 5 попыток в минуту с одного IP и 5 попыток за 10 минут '
            'на один номер телефона (номер участника — по сути пароль).'
        ),
        request=LoyaltyLoginSerializer,
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
                description='Неверный номер участника, либо ошибка валидации',
                examples=[
                    OpenApiExample('Неверный номер участника', value={'error': 'Неверный номер участника.'}),
                ],
            ),
            403: OpenApiResponse(description='Аккаунт заблокирован'),
            404: OpenApiResponse(
                description='Гость с таким номером телефона не найден в системе лояльности',
                examples=[
                    OpenApiExample('Не найден', value={'error': 'Гость с таким номером телефона не найден.'}),
                ],
            ),
            429: OpenApiResponse(description='Превышен лимит попыток'),
            503: OpenApiResponse(description='Сервис лояльности временно недоступен'),
        },
        examples=[
            OpenApiExample(
                'Запрос',
                value={'phone': '+77001234567', 'member_number': '100'},
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = LoyaltyLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data['phone']
        member_number = serializer.validated_data['member_number']

        from apps.remarked.client import RemarkedMobileClient
        from apps.remarked.exceptions import RemarkedAPIError

        try:
            guest = RemarkedMobileClient().get_info_by_phone(phone)
        except RemarkedAPIError as exc:
            logger.warning(
                "LoyaltyLoginView: Remarked lookup failed for phone=%s code=%s message=%s",
                phone, exc.code, exc.message,
            )
            return Response(
                {'error': 'Сервис лояльности временно недоступен. Попробуйте позже.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        if not guest:
            return Response(
                {'error': 'Гость с таким номером телефона не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # cards в ответе Remarked — список чисел/строк (наблюдалось ['100']),
        # тип элементов не документирован в openapi.json — сравниваем как строки.
        card_numbers = {str(c).strip() for c in (guest.get('cards') or [])}
        if member_number not in card_numbers:
            return Response(
                {'error': 'Неверный номер участника.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user, created = User.objects.get_or_create(phone=phone)
        if not user.is_active:
            return Response(
                {'error': 'Ваш аккаунт заблокирован.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        apply_guest_data_to_user(user, guest)

        update_last_login(None, user)
        refresh = RefreshToken.for_user(user)

        return Response({
            'message': 'Успешная авторизация',
            'is_new_user': created,
            'user_id': user.id,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })


@extend_schema(tags=['Auth'])
class LoyaltyRegisterView(APIView):
    """
    Регистрация нового гостя лояльности (ТЗ по входу, п.1) — форма повторяет
    состав полей выдачи карты в Apple Wallet. Создаёт гостя в Remarked (если
    его там ещё нет по этому телефону) и возвращает назначенный номер
    участника — Remarked присваивает его синхронно при создании (подтверждено
    эмпирически 2026-08-15, см. docs/piligrim_improvements_plan.md, Фаза B
    вопрос 1b), поэтому его можно сразу показать гостю.

    Если гость с этим телефоном уже есть в Remarked — 400 с указанием
    использовать вход, а не создавать дубликат/перезаписывать существующие
    данные.
    """
    permission_classes = [AllowAny]
    throttle_classes = [SafeScopedRateThrottle, LoyaltyRegisterPhoneThrottle]
    throttle_scope = 'loyalty_register'

    @extend_schema(
        summary='Регистрация нового гостя лояльности',
        description=(
            'Создаёт гостя в Remarked CRM и локальный аккаунт, возвращает '
            'назначенный номер участника (`member_number`) и пару JWT-токенов.\n\n'
            'Если гость с этим телефоном уже существует в Remarked — 400, '
            'нужно использовать /auth/loyalty-login/.\n\n'
            '**Лимит:** 3 попытки в минуту с одного IP и 3 попытки за 10 минут '
            'на один номер телефона.'
        ),
        request=LoyaltyRegisterSerializer,
        responses={
            200: OpenApiResponse(
                description='Регистрация успешна',
                examples=[
                    OpenApiExample(
                        'Успех',
                        value={
                            'message': 'Регистрация успешна',
                            'user_id': 42,
                            'member_number': '113',
                            'access': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<payload>.<signature>',
                            'refresh': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<payload>.<signature>',
                        },
                    )
                ],
            ),
            400: OpenApiResponse(
                description='Гость с этим телефоном уже зарегистрирован, либо ошибка валидации',
                examples=[
                    OpenApiExample(
                        'Уже зарегистрирован',
                        value={'error': 'Этот номер уже зарегистрирован. Используйте вход по номеру участника.'},
                    ),
                ],
            ),
            429: OpenApiResponse(description='Превышен лимит попыток'),
            503: OpenApiResponse(description='Сервис лояльности временно недоступен'),
        },
        examples=[
            OpenApiExample(
                'Запрос',
                value={
                    'phone': '+77001234567',
                    'first_name': 'Айдар',
                    'last_name': 'Нурланов',
                    'birthday': '1995-03-14',
                    'gender': 'male',
                },
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = LoyaltyRegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        phone = data['phone']

        from apps.remarked.client import RemarkedMobileClient
        from apps.remarked.exceptions import RemarkedAPIError

        client = RemarkedMobileClient()

        try:
            existing_guest = client.get_info_by_phone(phone)
        except RemarkedAPIError as exc:
            logger.warning(
                "LoyaltyRegisterView: Remarked lookup failed for phone=%s code=%s message=%s",
                phone, exc.code, exc.message,
            )
            return Response(
                {'error': 'Сервис лояльности временно недоступен. Попробуйте позже.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        if existing_guest:
            return Response(
                {'error': 'Этот номер уже зарегистрирован. Используйте вход по номеру участника.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Несохранённый User — create_or_update читает только атрибуты
        # (duck typing), реальную запись создаём отдельно ниже после
        # успешного ответа от Remarked.
        temp_user = User(
            phone=phone,
            first_name=data['first_name'],
            last_name=data.get('last_name') or '',
            gender=data['gender'],
            birthday=data.get('birthday'),
        )

        try:
            client.create_or_update(temp_user)
        except RemarkedAPIError as exc:
            logger.warning(
                "LoyaltyRegisterView: Remarked create failed for phone=%s code=%s message=%s",
                phone, exc.code, exc.message,
            )
            return Response(
                {'error': 'Сервис лояльности временно недоступен. Попробуйте позже.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Гость только что создан в Remarked — сразу после create_or_update
        # get_info_by_phone иногда не находит его (задержка индексации на
        # стороне Remarked, обнаружено эмпирически 2026-08-16). create_or_update
        # уже необратимо создал гостя, поэтому здесь НЕ возвращаем 503 —
        # просто пробуем прочитать карту с несколькими короткими попытками;
        # если не получится совсем, регистрация всё равно считается успешной
        # (без номера карты в ответе — гость сможет узнать его при следующем входе).
        guest = None
        for attempt in range(REMARKED_POST_CREATE_LOOKUP_ATTEMPTS):
            try:
                guest = client.get_info_by_phone(phone)
                break
            except RemarkedAPIError as exc:
                if attempt + 1 >= REMARKED_POST_CREATE_LOOKUP_ATTEMPTS:
                    logger.warning(
                        "LoyaltyRegisterView: post-create lookup failed for phone=%s after %d attempts: code=%s message=%s",
                        phone, REMARKED_POST_CREATE_LOOKUP_ATTEMPTS, exc.code, exc.message,
                    )
                else:
                    time.sleep(REMARKED_POST_CREATE_LOOKUP_DELAY)

        user, _ = User.objects.get_or_create(phone=phone)
        if guest:
            apply_guest_data_to_user(user, guest)

        member_number = None
        if guest:
            cards = guest.get('cards') or []
            if cards:
                member_number = str(cards[0])

        update_last_login(None, user)
        refresh = RefreshToken.for_user(user)

        return Response({
            'message': 'Регистрация успешна',
            'user_id': user.id,
            'member_number': member_number,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })


@extend_schema(tags=['Auth'])
class LogoutView(APIView):
    """
    Logout: принимает refresh-токен и помещает его в blacklist.
    После этого токен нельзя использовать для получения нового access-токена.
    """
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary='Выход из системы (отзыв refresh-токена)',
        description=(
            'Добавляет refresh-токен в blacklist, делая его недействительным.\n\n'
            'После logout клиент должен удалить оба токена (`access` и `refresh`) '
            'из локального хранилища и перенаправить пользователя на экран входа.\n\n'
            '**Важно:** access-токен продолжает работать до истечения своего TTL (30 мин в проде). '
            'Blacklist инвалидирует только возможность получить новый access через refresh.'
        ),
        request=LogoutSerializer,
        responses={
            204: OpenApiResponse(description='Успешный logout, тело пустое'),
            400: OpenApiResponse(
                description='Токен невалиден или уже отозван',
                examples=[
                    OpenApiExample('Ошибка', value={'error': 'Токен недействителен или уже отозван.'})
                ],
            ),
            401: _error_401,
        },
        examples=[
            OpenApiExample(
                'Запрос',
                value={'refresh': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<payload>.<signature>'},
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Парсим токен и добавляем в blacklist (запись в БД через token_blacklist)
            token = RefreshToken(serializer.validated_data['refresh'])
            token.blacklist()
        except TokenError:
            return Response(
                {'error': 'Токен недействителен или уже отозван.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=['Auth'])
class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'patch', 'head', 'options']

    @extend_schema(
        summary='Получить профиль текущего пользователя',
        description=(
            'Возвращает данные авторизованного пользователя: id, номер телефона, '
            'имя, фамилию, пол, email и дату рождения.'
        ),
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

    def perform_update(self, serializer):
        super().perform_update(serializer)
        # Пушим текущее состояние в Remarked, если у гостя уже есть remarked_guest_id
        # (upsert), либо анкета только что дала достаточно данных для первого
        # создания (см. maybe_push_guest_to_remarked).
        maybe_push_guest_to_remarked(serializer.instance)


@extend_schema(tags=['Auth'])
class DeleteAccountView(APIView):
    """
    Безвозвратное удаление аккаунта текущего пользователя (Guideline 5.1.1).
    Связанные брони, записи на события и FCM-устройства удаляются каскадом.
    """
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary='Удалить аккаунт текущего пользователя',
        description=(
            'Безвозвратно удаляет учётную запись и связанные персональные данные.\n\n'
            'После успешного ответа клиент должен очистить локальные JWT-токены '
            'и показать экран неавторизованного пользователя.\n\n'
            'Учётные записи персонала (`is_staff`) через приложение удалить нельзя.'
        ),
        responses={
            204: OpenApiResponse(description='Аккаунт удалён, тело пустое'),
            401: _error_401,
            403: OpenApiResponse(
                description='Удаление запрещено (например, staff-аккаунт)',
                examples=[
                    OpenApiExample(
                        'Запрещено',
                        value={'error': 'Этот аккаунт нельзя удалить через приложение.'},
                    )
                ],
            ),
        },
    )
    def delete(self, request):
        user = request.user
        if user.is_staff or user.is_superuser:
            return Response(
                {'error': 'Этот аккаунт нельзя удалить через приложение.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

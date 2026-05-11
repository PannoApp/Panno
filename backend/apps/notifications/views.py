from rest_framework import status, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema, OpenApiExample, OpenApiResponse
from .models import UserDevice
from .serializers import UserDeviceSerializer


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

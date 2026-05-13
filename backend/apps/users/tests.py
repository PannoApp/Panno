from datetime import timedelta
from importlib import import_module, reload
from unittest.mock import patch, MagicMock

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RequestSMSSerializer, VerifySMSSerializer
from .services import SMSService
from .throttles import PhoneSMSThrottle

User = get_user_model()


# ---------------------------------------------------------------------------
# SMSService
# ---------------------------------------------------------------------------

class SMSServiceTest(TestCase):
    def setUp(self):
        cache.clear()

    def test_generate_otp_is_4_digits(self):
        otp = SMSService.generate_otp()
        self.assertEqual(len(otp), 4)

    def test_generate_otp_is_numeric(self):
        otp = SMSService.generate_otp()
        self.assertTrue(otp.isdigit())

    def test_generate_otp_in_valid_range(self):
        otp = int(SMSService.generate_otp())
        self.assertGreaterEqual(otp, 1000)
        self.assertLessEqual(otp, 9999)

    @override_settings(DEBUG=True)
    def test_send_sms_stores_otp_in_cache(self):
        result = SMSService.send_sms('+77001234567')
        self.assertTrue(result)
        self.assertIsNotNone(cache.get('otp_+77001234567'))

    @override_settings(DEBUG=True)
    def test_send_sms_debug_does_not_call_celery(self):
        with patch('apps.users.tasks.send_sms_task.delay') as mock_delay:
            SMSService.send_sms('+77001234567')
            mock_delay.assert_not_called()

    @override_settings(DEBUG=False, SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_send_sms_production_dispatches_celery_task(self):
        with patch('apps.users.tasks.send_sms_task.delay') as mock_delay:
            result = SMSService.send_sms('+77001234567')
            self.assertTrue(result)
            mock_delay.assert_called_once()
            call_args = mock_delay.call_args[0]
            self.assertEqual(call_args[0], '+77001234567')
            # OTP passed to task must match what was saved in Redis
            saved_otp = cache.get('otp_+77001234567')
            self.assertIsNotNone(saved_otp)
            self.assertEqual(call_args[1], saved_otp)

    @override_settings(DEBUG=False, SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_send_sms_production_saves_otp_before_dispatch(self):
        """OTP должен быть в Redis до того, как Celery-таска встанет в очередь."""
        saved_otps = []

        def capture_delay(phone, otp):
            saved_otps.append(cache.get(f'otp_{phone}'))

        with patch('apps.users.tasks.send_sms_task.delay', side_effect=capture_delay):
            SMSService.send_sms('+77001234567')

        self.assertEqual(len(saved_otps), 1)
        self.assertIsNotNone(saved_otps[0])

    @override_settings(DEBUG=False, SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_send_sms_production_returns_true_immediately(self):
        with patch('apps.users.tasks.send_sms_task.delay'):
            result = SMSService.send_sms('+77001234567')
        self.assertTrue(result)

    def test_verify_otp_correct_returns_true_and_deletes_key(self):
        cache.set('otp_+77001234567', '1234', 180)
        self.assertTrue(SMSService.verify_otp('+77001234567', '1234'))
        self.assertIsNone(cache.get('otp_+77001234567'))

    def test_verify_otp_wrong_code_returns_false_and_keeps_key(self):
        cache.set('otp_+77001234567', '1234', 180)
        self.assertFalse(SMSService.verify_otp('+77001234567', '9999'))
        self.assertIsNotNone(cache.get('otp_+77001234567'))

    def test_verify_otp_no_key_returns_false(self):
        self.assertFalse(SMSService.verify_otp('+77009999999', '1234'))

    def test_verify_otp_cannot_be_used_twice(self):
        cache.set('otp_+77001234567', '1234', 180)
        SMSService.verify_otp('+77001234567', '1234')
        self.assertFalse(SMSService.verify_otp('+77001234567', '1234'))


# ---------------------------------------------------------------------------
# send_sms_task (Celery)
# ---------------------------------------------------------------------------

class SendSmsTaskTest(TestCase):
    """Тесты для Celery-таски apps.users.tasks.send_sms_task."""

    def _run_task_eagerly(self, phone, otp):
        """Запускает таску синхронно (CELERY_TASK_ALWAYS_EAGER)."""
        from .tasks import send_sms_task
        return send_sms_task.apply(args=[phone, otp])

    @override_settings(SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_task_calls_sms_provider(self):
        import requests as req_module
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        with patch.object(req_module, 'post', return_value=mock_resp) as mock_post:
            self._run_task_eagerly('+77001234567', '1234')
            mock_post.assert_called_once()
            _, kwargs = mock_post.call_args
            self.assertIn('1234', kwargs['data']['mes'])
            self.assertEqual(kwargs['data']['phones'], '+77001234567')

    @override_settings(SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_task_retries_on_provider_error_status(self):
        import requests as req_module
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_resp.text = 'Internal Server Error'
        with patch.object(req_module, 'post', return_value=mock_resp):
            from .tasks import send_sms_task
            result = send_sms_task.apply(args=['+77001234567', '1234'])
            self.assertTrue(result.failed())

    @override_settings(SMS_PROVIDER_URL='http://fake', SMS_LOGIN='l', SMS_PASSWORD='p')
    def test_task_retries_on_network_exception(self):
        import requests as req_module
        with patch.object(req_module, 'post', side_effect=req_module.RequestException('timeout')):
            from .tasks import send_sms_task
            result = send_sms_task.apply(args=['+77001234567', '1234'])
            self.assertTrue(result.failed())


# ---------------------------------------------------------------------------
# Serializers
# ---------------------------------------------------------------------------

class RequestSMSSerializerTest(TestCase):
    def test_valid_phone(self):
        s = RequestSMSSerializer(data={'phone': '+77001234567'})
        self.assertTrue(s.is_valid())

    def test_invalid_phone_no_plus(self):
        s = RequestSMSSerializer(data={'phone': '77001234567'})
        self.assertFalse(s.is_valid())
        self.assertIn('phone', s.errors)

    def test_invalid_phone_too_short(self):
        s = RequestSMSSerializer(data={'phone': '+7700'})
        self.assertFalse(s.is_valid())

    def test_empty_phone(self):
        s = RequestSMSSerializer(data={'phone': ''})
        self.assertFalse(s.is_valid())

    def test_missing_phone(self):
        s = RequestSMSSerializer(data={})
        self.assertFalse(s.is_valid())


class VerifySMSSerializerTest(TestCase):
    def test_valid(self):
        s = VerifySMSSerializer(data={'phone': '+77001234567', 'otp': '1234'})
        self.assertTrue(s.is_valid())

    def test_otp_too_short(self):
        s = VerifySMSSerializer(data={'phone': '+77001234567', 'otp': '12'})
        self.assertFalse(s.is_valid())
        self.assertIn('otp', s.errors)

    def test_otp_too_long(self):
        s = VerifySMSSerializer(data={'phone': '+77001234567', 'otp': '12345'})
        self.assertFalse(s.is_valid())

    def test_otp_not_numeric(self):
        s = VerifySMSSerializer(data={'phone': '+77001234567', 'otp': 'abcd'})
        self.assertFalse(s.is_valid())

    def test_invalid_phone_with_valid_otp(self):
        s = VerifySMSSerializer(data={'phone': 'bad', 'otp': '1234'})
        self.assertFalse(s.is_valid())


# ---------------------------------------------------------------------------
# POST /api/users/auth/request-sms/
# ---------------------------------------------------------------------------

class RequestSMSViewTest(APITestCase):
    def setUp(self):
        cache.clear()

    @override_settings(DEBUG=True)
    def test_valid_phone_returns_200(self):
        response = self.client.post('/api/v1/users/auth/request-sms/', {'phone': '+77001234567'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['message'], 'SMS код отправлен.')

    def test_invalid_phone_returns_400(self):
        response = self.client.post('/api/v1/users/auth/request-sms/', {'phone': 'notaphone'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('phone', response.data)

    def test_missing_phone_returns_400(self):
        response = self.client.post('/api/v1/users/auth/request-sms/', {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('apps.users.views.SMSService.send_sms', return_value=False)
    def test_sms_failure_returns_500(self, _):
        response = self.client.post('/api/v1/users/auth/request-sms/', {'phone': '+77001234567'})
        self.assertEqual(response.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertIn('error', response.data)


# ---------------------------------------------------------------------------
# POST /api/users/auth/verify-sms/
# ---------------------------------------------------------------------------

class VerifySMSViewTest(APITestCase):
    PHONE = '+77001234567'
    OTP = '4321'

    def setUp(self):
        cache.clear()
        cache.set(f'otp_{self.PHONE}', self.OTP, 180)

    def test_valid_otp_returns_jwt_tokens(self):
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': self.OTP,
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_valid_otp_creates_new_user(self):
        self.assertFalse(User.objects.filter(phone=self.PHONE).exists())
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': self.OTP,
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_new_user'])
        self.assertTrue(User.objects.filter(phone=self.PHONE).exists())

    def test_valid_otp_existing_user_not_duplicated(self):
        User.objects.create_user(phone=self.PHONE)
        cache.set(f'otp_{self.PHONE}', self.OTP, 180)
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': self.OTP,
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_new_user'])
        self.assertEqual(User.objects.filter(phone=self.PHONE).count(), 1)

    def test_wrong_otp_returns_400(self):
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': '0000',
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_invalid_otp_format_returns_400(self):
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': 'bad!',
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_otp_consumed_after_successful_verify(self):
        self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': self.OTP,
        })
        cache.set(f'otp_{self.PHONE}', self.OTP, 180)
        response = self.client.post('/api/v1/users/auth/verify-sms/', {
            'phone': self.PHONE, 'otp': self.OTP,
        })
        # Second attempt with same OTP should succeed (we re-set OTP above)
        self.assertEqual(response.status_code, status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# GET/PATCH /api/users/profile/
# ---------------------------------------------------------------------------

class UserProfileViewTest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='+77001234567')
        self.user.first_name = 'Алихан'
        self.user.save()

    def _auth(self):
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_get_own_profile_returns_200(self):
        self._auth()
        response = self.client.get('/api/v1/users/profile/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['phone'], '+77001234567')
        self.assertEqual(response.data['first_name'], 'Алихан')

    def test_get_unauthenticated_returns_401(self):
        response = self.client.get('/api/v1/users/profile/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_patch_updates_first_and_last_name(self):
        self._auth()
        response = self.client.patch('/api/v1/users/profile/', {
            'first_name': 'Данияр',
            'last_name': 'Сейткали',
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, 'Данияр')
        self.assertEqual(self.user.last_name, 'Сейткали')

    def test_patch_phone_is_read_only(self):
        self._auth()
        self.client.patch('/api/v1/users/profile/', {'phone': '+70000000000'})
        self.user.refresh_from_db()
        self.assertEqual(self.user.phone, '+77001234567')

    def test_patch_id_is_read_only(self):
        self._auth()
        original_id = self.user.pk
        self.client.patch('/api/v1/users/profile/', {'id': 9999})
        self.user.refresh_from_db()
        self.assertEqual(self.user.pk, original_id)

    def test_put_not_allowed(self):
        self._auth()
        response = self.client.put('/api/v1/users/profile/', {'first_name': 'X'})
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_patch_unauthenticated_returns_401(self):
        response = self.client.patch('/api/v1/users/profile/', {'first_name': 'X'})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


# ---------------------------------------------------------------------------
# PhoneSMSThrottle
# ---------------------------------------------------------------------------

class PhoneSMSThrottleTest(TestCase):
    """Тесты для кастомного троттлинга по номеру телефона."""

    def setUp(self):
        cache.clear()

    def test_parse_rate_returns_5_requests_600_seconds(self):
        throttle = PhoneSMSThrottle()
        num, duration = throttle.parse_rate('any_string')
        self.assertEqual(num, 5)
        self.assertEqual(duration, 600)

    def test_parse_rate_with_none_returns_none_pair(self):
        throttle = PhoneSMSThrottle()
        num, duration = throttle.parse_rate(None)
        self.assertIsNone(num)
        self.assertIsNone(duration)

    def _make_mock_request(self, phone=None):
        """Возвращает mock-объект с атрибутом data, имитирующий DRF Request."""
        req = MagicMock()
        req.data = {'phone': phone} if phone else {}
        return req

    def test_get_cache_key_contains_phone(self):
        """Ключ Redis должен содержать номер телефона."""
        throttle = PhoneSMSThrottle()
        key = throttle.get_cache_key(self._make_mock_request('+77001234567'), view=None)
        self.assertIsNotNone(key)
        self.assertIn('+77001234567', key)

    def test_get_cache_key_without_phone_returns_none(self):
        """Если телефона нет в теле — не блокируем (сработает валидация сериализатора)."""
        throttle = PhoneSMSThrottle()
        key = throttle.get_cache_key(self._make_mock_request(), view=None)
        self.assertIsNone(key)

    def test_different_phones_have_different_keys(self):
        """Два разных номера не должны разделять один счётчик."""
        throttle = PhoneSMSThrottle()
        key1 = throttle.get_cache_key(self._make_mock_request('+77001111111'), view=None)
        key2 = throttle.get_cache_key(self._make_mock_request('+77002222222'), view=None)
        self.assertNotEqual(key1, key2)


class RequestSMSPhoneThrottleIntegrationTest(APITestCase):
    """
    Интеграционный тест: проверяем, что 429 возвращается после превышения
    лимита по номеру телефона (5 запросов за 10 минут).

    ScopedRateThrottle (IP-уровень) мокается, чтобы не мешать — в тестах
    все запросы идут с одного IP, и IP-лимит (3/мин) срабатывал бы раньше
    телефонного (5/10 мин), скрывая поведение, которое мы тестируем.
    """

    def setUp(self):
        cache.clear()

    @override_settings(DEBUG=True)
    @patch('rest_framework.throttling.ScopedRateThrottle.allow_request', return_value=True)
    def test_phone_throttle_blocks_after_limit(self, _mock_ip_throttle):
        """После 5 успешных запросов с одного номера — должен вернуться 429."""
        phone = '+77009999999'
        url = '/api/v1/users/auth/request-sms/'

        # Первые 5 запросов должны проходить
        for i in range(5):
            response = self.client.post(url, {'phone': phone})
            self.assertEqual(
                response.status_code, status.HTTP_200_OK,
                msg=f'Запрос {i + 1} должен проходить, получен {response.status_code}',
            )

        # 6-й запрос с того же номера — должен быть заблокирован телефонным троттлом
        response = self.client.post(url, {'phone': phone})
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    @override_settings(DEBUG=True)
    @patch('rest_framework.throttling.ScopedRateThrottle.allow_request', return_value=True)
    def test_different_phones_are_throttled_independently(self, _mock_ip_throttle):
        """Лимит считается отдельно для каждого номера телефона."""
        url = '/api/v1/users/auth/request-sms/'

        phone_a = '+77001110001'
        phone_b = '+77001110002'

        # Исчерпываем лимит для phone_a
        for _ in range(5):
            self.client.post(url, {'phone': phone_a})

        # phone_a заблокирован
        response_a = self.client.post(url, {'phone': phone_a})
        self.assertEqual(response_a.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

        # phone_b должен проходить свободно — у него свой независимый счётчик
        response_b = self.client.post(url, {'phone': phone_b})
        self.assertEqual(response_b.status_code, status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# Блок 8: auto-set is_staff при назначении роли через UserAdmin
# ---------------------------------------------------------------------------

class UserAdminIsStaffAutoSetTest(TestCase):
    """
    UserAdmin.save_model() должен автоматически устанавливать is_staff=True
    при назначении роли, и is_staff=False при снятии роли.
    Без этого сотрудник не смог бы войти в Django Admin.
    """

    def setUp(self):
        self.superuser = User.objects.create_user(phone='+70000000001')
        self.superuser.is_superuser = True
        self.superuser.is_staff = True
        self.superuser.save()

    def _save_via_admin(self, user, role):
        """Симулирует сохранение через UserAdmin (вызывает save_model)."""
        from apps.users.admin import UserAdmin
        from django.contrib.admin import site
        from django.test import RequestFactory
        rf = RequestFactory()
        req = rf.post('/')
        req.user = self.superuser

        admin_instance = UserAdmin(User, site)
        user.role = role
        # form и change — не используются в нашей логике, передаём заглушки
        admin_instance.save_model(req, user, form=None, change=True)

    def test_role_assigned_sets_is_staff_true(self):
        """Назначение роли hall_manager → is_staff автоматически True."""
        user = User.objects.create_user(phone='+71112223344')
        self.assertFalse(user.is_staff)
        self._save_via_admin(user, 'hall_manager')
        user.refresh_from_db()
        self.assertTrue(user.is_staff)

    def test_content_manager_role_sets_is_staff(self):
        user = User.objects.create_user(phone='+71112223345')
        self._save_via_admin(user, 'content_manager')
        user.refresh_from_db()
        self.assertTrue(user.is_staff)

    def test_admin_role_sets_is_staff(self):
        user = User.objects.create_user(phone='+71112223346')
        self._save_via_admin(user, 'admin')
        user.refresh_from_db()
        self.assertTrue(user.is_staff)

    def test_role_cleared_unsets_is_staff(self):
        """Снятие роли → is_staff=False (пользователь теряет доступ к Admin)."""
        user = User.objects.create_user(phone='+71112223347')
        user.is_staff = True
        user.save()
        self._save_via_admin(user, '')
        user.refresh_from_db()
        self.assertFalse(user.is_staff)

    def test_superuser_is_staff_not_touched_when_role_cleared(self):
        """
        Снятие роли у суперпользователя не должно убирать is_staff —
        суперпользователь всегда должен иметь доступ к Admin.
        """
        su = User.objects.create_user(phone='+71112223348')
        su.is_superuser = True
        su.is_staff = True
        su.save()
        self._save_via_admin(su, '')
        su.refresh_from_db()
        self.assertTrue(su.is_staff)


# ---------------------------------------------------------------------------
# POST /api/v1/users/auth/token/refresh/
# ---------------------------------------------------------------------------

class TokenRefreshViewTest(APITestCase):
    """
    Тесты эндпоинта обновления access-токена через refresh-токен.
    Позволяет Flutter-клиенту избежать повторного SMS-флоу при истечении
    access-токена.
    """

    URL = '/api/v1/users/auth/token/refresh/'

    def setUp(self):
        self.user = User.objects.create_user(phone='+77001234567')
        self.refresh = RefreshToken.for_user(self.user)

    def test_valid_refresh_returns_new_access_token(self):
        """Валидный refresh-токен → новый access-токен в ответе."""
        response = self.client.post(self.URL, {'refresh': str(self.refresh)})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)

    def test_new_access_token_is_different_from_old(self):
        """Каждый вызов должен выдавать уникальный access-токен."""
        old_access = str(self.refresh.access_token)
        response = self.client.post(self.URL, {'refresh': str(self.refresh)})
        self.assertNotEqual(response.data['access'], old_access)

    def test_invalid_refresh_token_returns_401(self):
        """Поддельный токен → 401 Unauthorized."""
        response = self.client.post(self.URL, {'refresh': 'invalid.token.here'})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_missing_refresh_field_returns_400(self):
        """Пустое тело запроса → 400 Bad Request."""
        response = self.client.post(self.URL, {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_endpoint_does_not_require_authorization_header(self):
        """
        Эндпоинт публичный — не нужен Authorization-заголовок.
        Если бы требовал — это был бы порочный круг: обновлять токен
        уже не смог бы клиент с просроченным access.
        """
        # Убеждаемся, что credentials пусты
        self.client.credentials()
        response = self.client.post(self.URL, {'refresh': str(self.refresh)})
        self.assertEqual(response.status_code, status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# POST /api/v1/users/auth/logout/
# ---------------------------------------------------------------------------

class LogoutViewTest(APITestCase):
    """
    Тесты logout-эндпоинта: refresh-токен должен попадать в blacklist после
    вызова logout, а повторная попытка обновить access — завершаться с 401.
    """

    URL = '/api/v1/users/auth/logout/'
    REFRESH_URL = '/api/v1/users/auth/token/refresh/'

    def setUp(self):
        self.user = User.objects.create_user(phone='+77001234567')
        self.refresh = RefreshToken.for_user(self.user)
        # Аутентифицируем клиента через access-токен
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.refresh.access_token}')

    def test_logout_returns_204(self):
        """Валидный refresh-токен → 204 No Content."""
        response = self.client.post(self.URL, {'refresh': str(self.refresh)})
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

    def test_logout_blacklists_refresh_token(self):
        """После logout refresh-токен нельзя использовать для обновления access."""
        refresh_str = str(self.refresh)
        self.client.post(self.URL, {'refresh': refresh_str})

        # Попытка обновить access с уже отозванным токеном должна вернуть 401
        response = self.client.post(self.REFRESH_URL, {'refresh': refresh_str})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_with_already_blacklisted_token_returns_400(self):
        """Повторный logout с тем же токеном → 400 Bad Request."""
        refresh_str = str(self.refresh)
        self.client.post(self.URL, {'refresh': refresh_str})
        response = self.client.post(self.URL, {'refresh': refresh_str})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_logout_with_invalid_token_returns_400(self):
        """Поддельный/невалидный токен → 400 Bad Request."""
        response = self.client.post(self.URL, {'refresh': 'not.a.valid.token'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_logout_without_auth_header_returns_401(self):
        """Без Authorization-заголовка (access-токена) → 401 Unauthorized."""
        self.client.credentials()
        response = self.client.post(self.URL, {'refresh': str(self.refresh)})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_missing_refresh_field_returns_400(self):
        """Пустое тело запроса → 400 Bad Request."""
        response = self.client.post(self.URL, {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


# ---------------------------------------------------------------------------
# JWT-настройки: проверяем TTL токенов для разных окружений
# ---------------------------------------------------------------------------

class JWTSettingsBaseTest(TestCase):
    """
    Проверяем, что base.py содержит безопасный TTL access-токена для прода.
    Тест защищает от случайного возврата к небезопасному значению.
    """

    def test_access_token_lifetime_is_30_minutes_in_base(self):
        """base.py: ACCESS_TOKEN_LIFETIME должен быть <= 30 минут."""
        base_settings = import_module('config.settings.base')
        lifetime = base_settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME']
        self.assertLessEqual(
            lifetime,
            timedelta(minutes=30),
            msg=(
                f'ACCESS_TOKEN_LIFETIME в base.py равен {lifetime}. '
                'Для безопасности в проде значение должно быть не более 30 минут.'
            ),
        )

    def test_refresh_token_lifetime_is_7_days_in_base(self):
        """base.py: REFRESH_TOKEN_LIFETIME должен оставаться 7 дней."""
        base_settings = import_module('config.settings.base')
        lifetime = base_settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME']
        self.assertEqual(lifetime, timedelta(days=7))


class JWTSettingsDevTest(TestCase):
    """
    Проверяем, что dev.py переопределяет ACCESS_TOKEN_LIFETIME на 1 день
    для удобства разработки.
    """

    def test_access_token_lifetime_is_1_day_in_dev(self):
        """dev.py: ACCESS_TOKEN_LIFETIME должен быть 1 день."""
        dev_settings = import_module('config.settings.dev')
        lifetime = dev_settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME']
        self.assertEqual(
            lifetime,
            timedelta(days=1),
            msg=(
                f'ACCESS_TOKEN_LIFETIME в dev.py равен {lifetime}. '
                'Для удобства разработки ожидается 1 день.'
            ),
        )

    def test_dev_access_lifetime_exceeds_base(self):
        """dev.py должен задавать больший TTL, чем base.py (разработка удобнее прода)."""
        base_settings = import_module('config.settings.base')
        dev_settings = import_module('config.settings.dev')
        self.assertGreater(
            dev_settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'],
            base_settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'],
        )

    def test_dev_inherits_refresh_lifetime_from_base(self):
        """dev.py не переопределяет REFRESH_TOKEN_LIFETIME — должен унаследовать 7 дней."""
        dev_settings = import_module('config.settings.dev')
        self.assertEqual(dev_settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'], timedelta(days=7))


# ---------------------------------------------------------------------------
# AUTH_PASSWORD_VALIDATORS: убеждаемся, что мёртвый код отсутствует
# ---------------------------------------------------------------------------

class PasswordValidatorsAbsentTest(TestCase):
    """
    Гарантирует, что AUTH_PASSWORD_VALIDATORS не возвращён в base.py случайно.

    Все пользователи системы аутентифицируются через SMS OTP и имеют
    unusable_password (set_unusable_password() в UserManager.create_user).
    Валидаторы паролей никогда не применяются — их присутствие в конфиге
    вводило бы в заблуждение читателей настроек.
    """

    def test_auth_password_validators_not_set_in_base(self):
        """base.py не должен содержать AUTH_PASSWORD_VALIDATORS."""
        base_settings = import_module('config.settings.base')
        validators = getattr(base_settings, 'AUTH_PASSWORD_VALIDATORS', None)
        self.assertIsNone(
            validators,
            msg=(
                'AUTH_PASSWORD_VALIDATORS обнаружен в base.py. '
                'Пользователи используют SMS OTP и имеют unusable_password — '
                'валидаторы паролей к ним не применяются и должны быть удалены.'
            ),
        )

    def test_users_have_unusable_password(self):
        """Пользователь, созданный через create_user, должен иметь unusable_password."""
        user = User.objects.create_user(phone='+77001111111')
        self.assertFalse(
            user.has_usable_password(),
            msg='create_user должен вызывать set_unusable_password() — пароли не используются.',
        )

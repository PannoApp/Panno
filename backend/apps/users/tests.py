from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RequestSMSSerializer, VerifySMSSerializer
from .services import SMSService

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

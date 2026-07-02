from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from django.test import TestCase
from rest_framework.test import APIRequestFactory
from rest_framework.views import APIView

from utils.permissions import IsStaffOrAdmin

User = get_user_model()


class IsStaffOrAdminTest(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.permission = IsStaffOrAdmin()
        self.view = APIView()

    def _request(self, user):
        request = self.factory.get('/')
        request.user = user
        return request

    def test_staff_user_allowed(self):
        user = User.objects.create_user(phone='+70000000001', role='admin')
        self.assertTrue(self.permission.has_permission(self._request(user), self.view))

    def test_regular_user_denied(self):
        user = User.objects.create_user(phone='+70000000002')
        self.assertFalse(self.permission.has_permission(self._request(user), self.view))

    def test_anonymous_denied(self):
        self.assertFalse(self.permission.has_permission(self._request(AnonymousUser()), self.view))

    def test_superuser_allowed(self):
        user = User.objects.create_superuser(phone='+70000000003')
        self.assertTrue(self.permission.has_permission(self._request(user), self.view))

"""
Health check endpoint для мониторинга работоспособности сервисов.
Используется DevOps/деплой-системами, не предназначен для Flutter.

GET /api/v1/health/
  200 — все сервисы работают
  503 — хотя бы один сервис недоступен
"""

import logging

from django.core.cache import cache
from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

logger = logging.getLogger(__name__)


class HealthCheckView(APIView):
    """Возвращает статус DB и Redis. Не требует авторизации."""

    permission_classes = [AllowAny]
    # Исключаем из throttling — этот эндпоинт вызывается мониторингом
    throttle_classes = []

    def get(self, request):
        db_status = self._check_db()
        redis_status = self._check_redis()

        all_ok = db_status == "ok" and redis_status == "ok"

        payload = {
            "status": "ok" if all_ok else "degraded",
            "db": db_status,
            "redis": redis_status,
        }
        http_status = 200 if all_ok else 503
        return Response(payload, status=http_status)

    @staticmethod
    def _check_db() -> str:
        """Делает минимальный запрос к БД для проверки соединения."""
        try:
            connection.ensure_connection()
            return "ok"
        except Exception as exc:  # noqa: BLE001
            logger.warning("Health check: DB недоступна — %s", exc)
            return "error"

    @staticmethod
    def _check_redis() -> str:
        """Пишет и читает ключ из кэша для проверки Redis."""
        try:
            cache.set("health_check", "1", timeout=5)
            if cache.get("health_check") != "1":
                raise RuntimeError("cache get/set mismatch")
            return "ok"
        except Exception as exc:  # noqa: BLE001
            logger.warning("Health check: Redis недоступен — %s", exc)
            return "error"

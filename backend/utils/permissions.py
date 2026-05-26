from rest_framework.permissions import BasePermission


def _has_role(user, *roles):
    return user.is_authenticated and (
        user.is_superuser or getattr(user, 'role', '') in roles
    )


class IsAdminRole(BasePermission):
    """Полный доступ: role='admin' или is_superuser."""
    def has_permission(self, request, view):
        return _has_role(request.user, 'admin')


class IsHallManager(BasePermission):
    """Брони и заявки на мероприятия: role in ('admin', 'hall_manager') или is_superuser."""
    def has_permission(self, request, view):
        return _has_role(request.user, 'admin', 'hall_manager')


class IsContentManager(BasePermission):
    """Меню, афиша, новости, push-рассылки: role in ('admin', 'content_manager') или is_superuser."""
    def has_permission(self, request, view):
        return _has_role(request.user, 'admin', 'content_manager')


class IsStaffOrAdmin(BasePermission):
    """Любой staff-пользователь (is_staff=True). AnonymousUser отклоняется без AttributeError."""
    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_staff
        )

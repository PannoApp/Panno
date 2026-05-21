from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin

class UserManager(BaseUserManager):
    def create_user(self, phone, password=None, **extra_fields):
        if not phone:
            raise ValueError("Номер телефона обязателен")
        
        user = self.model(phone=phone, **extra_fields)
        
        if password:
            # Если пароль передан (для админа), хешируем и сохраняем его
            user.set_password(password)
        else:
            # Если пароля нет (для обычных юзеров с SMS), делаем его непригодным
            user.set_unusable_password()
            
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self.create_user(phone, password, **extra_fields)

class User(AbstractBaseUser, PermissionsMixin):
    phone = models.CharField(max_length=15, unique=True, verbose_name="Номер телефона")
    first_name = models.CharField(max_length=150, blank=True, verbose_name="Имя")
    last_name = models.CharField(max_length=50, blank=True, verbose_name="Фамилия")
    
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    ROLE_CHOICES = [
        ('admin', 'Администратор'),
        ('hall_manager', 'Менеджер зала'),
        ('content_manager', 'Контент-менеджер'),
    ]
    role = models.CharField("Роль", max_length=20, choices=ROLE_CHOICES, blank=True)

    notifications_enabled = models.BooleanField(default=True)
    telegram_id = models.CharField(
        "Telegram ID",
        max_length=100,
        blank=True,
        null=True,
        unique=True,
        help_text="ID чата менеджера в Telegram для авторизации в боте."
    )

    # Город пользователя — заполняется из геолокации на стороне приложения (если разрешена).
    # Используется для сегментирования push-рассылок по городу/региону.
    city = models.CharField("Город", max_length=100, blank=True, default='')

    # Категорийные настройки уведомлений (сервисные уведомления — бронь — не отключаются)
    notify_events = models.BooleanField("Уведомления: мероприятия", default=True)
    notify_promotions = models.BooleanField("Уведомления: акции", default=True)
    notify_closed_events = models.BooleanField("Уведомления: закрытые события", default=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    # УДАЛИ СТРОЧКУ password = None, если ты её успел добавить.
    # AbstractBaseUser уже содержит поле password. 
    # Оно нужно, чтобы ты мог войти в админку.

    class Meta:
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"
        indexes = [
            # Индекс для сегментирования пользователей по городу (push-рассылки по региону)
            models.Index(fields=['city'], name='user_city_idx'),
            # Индекс для сортировки/фильтрации по дате регистрации (аналитика)
            models.Index(fields=['date_joined'], name='user_date_joined_idx'),
        ]

    def save(self, *args, **kwargs):
        # Синхронизируем is_staff с полем role при любом сохранении:
        # любая непустая роль → is_staff=True (доступ в Admin + staff API).
        # Снятие роли у обычного пользователя → is_staff=False.
        # Суперпользователь не затрагивается — его is_staff управляется отдельно.
        if self.role:
            self.is_staff = True
        elif not self.is_superuser:
            self.is_staff = False
        super().save(*args, **kwargs)

    def __str__(self):
        return self.phone
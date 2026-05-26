# Проект: Admin Events/News CRUD + Dish Video Upload

**Статус:** Планирование
**Стек:** Django REST Framework + Flutter
**Scope:** Feature 1 — Admin CRUD для мероприятий и новостей из Flutter-приложения. Feature 2 — загрузка видео к блюду через Staff API.
**Принцип:** один тикет = одна изолированная задача, покрытая тестом. Ничего не трогать в существующем рабочем коде без необходимости.

---

## Контекст

Оба feature используют уже существующую инфраструктуру:
- `IsStaffOrAdmin` permission — уже в `backend/utils/permissions.py`
- `AutoCropImageMixin` — уже в `utils/image_processing.py`, примешан в `Event`, `News`, `Dish`
- `StaffDishViewSet` + `DishEditScreen` — паттерн полностью реализован, копируем
- Сигналы инвалидации кэша событий — уже в `backend/apps/events/signals.py`
- Сигнал `trigger_video_processing` — уже в `backend/apps/menu/signals.py`
- Celery-задача `process_dish_video` — уже в `backend/apps/menu/tasks.py`
- `video`, `video_processed`, `video_status` — уже в модели `Dish`
- `image_picker` и `image_cropper` — уже в `pubspec.yaml` и настроены нативно

---

## Блок 1 — Backend: Staff-сериализаторы для Events и News

### TICKET-022 — Создать `StaffEventSerializer`

**Файл:** `backend/apps/events/serializers.py`
**Зависимости:** нет
**Тест:** TICKET-022-T

#### Технические шаги
- [ ] Добавить `StaffEventSerializer(ModelSerializer)` в конец `serializers.py`, **не трогая** `EventSerializer`
- [ ] Поля:
  - `title`, `description`, `date_time` — обычные поля модели
  - `image` → `ImageField(required=False)` — multipart
  - `image_url` → `SerializerMethodField`, возвращает абсолютный URL через `request.build_absolute_uri(obj.image.url)`, `None` если нет изображения
  - `format` → `CharField(default='open')` с явной валидацией допустимых значений `['open', 'closed']`
  - `price` → `DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)`
  - `is_active` → `BooleanField(default=True)`
  - `max_places` → `IntegerField(default=0, required=False)`
  - `created_at` → `read_only=True`
  - `occupied_places` → `read_only=True` (вычисляемое свойство модели)
- [ ] В `validate()` добавить: если `self.instance is None` и `image` отсутствует → `raise ValidationError({'image': 'Обложка обязательна при создании мероприятия.'})`
- [ ] `Meta.fields` содержит все поля выше; `Meta.read_only_fields` = `('id', 'created_at', 'occupied_places')`
- [ ] Убедиться что `AutoCropImageMixin` в `Event.save()` срабатывает автоматически при сохранении через сериализатор

#### Тест TICKET-022-T
**Файл:** `backend/apps/events/tests/test_staff_event_serializer.py`
- [ ] `test_valid_create_with_image` — все обязательные поля + изображение → `is_valid() == True`
- [ ] `test_create_without_image_invalid` — без `image` при создании → `ValidationError` с ключом `image`
- [ ] `test_partial_update_without_image_valid` — PATCH без image при наличии `instance` → valid
- [ ] `test_format_choices_validation` — `format='invalid'` → `ValidationError` с ключом `format`
- [ ] `test_image_url_is_absolute` — создать Event через ORM, сериализовать с `context={'request': mock_request}` → `image_url` начинается с `http://`
- [ ] `test_price_nullable` — `price=None` → valid, `price='1500.00'` → valid
- [ ] `test_occupied_places_is_readonly` — передать `occupied_places=99` → значение игнорируется

---

### TICKET-023 — Создать `StaffNewsSerializer`

**Файл:** `backend/apps/events/serializers.py`
**Зависимости:** нет
**Тест:** TICKET-023-T

#### Технические шаги
- [ ] Добавить `StaffNewsSerializer(ModelSerializer)` в конец `serializers.py`, **не трогая** `NewsSerializer`
- [ ] Поля:
  - `title` — CharField, required
  - `content` — TextField, required
  - `image` → `ImageField(required=False, allow_null=True)` — изображение необязательно
  - `image_url` → `SerializerMethodField`, возвращает абсолютный URL или `None`
  - `created_at` → `read_only=True`
- [ ] **Не добавлять** обязательную проверку image при создании — новость без картинки допустима
- [ ] `Meta.read_only_fields` = `('id', 'created_at')`

#### Тест TICKET-023-T
**Файл:** `backend/apps/events/tests/test_staff_news_serializer.py`
- [ ] `test_valid_create_without_image` — только `title` + `content` → valid
- [ ] `test_valid_create_with_image` — с изображением → valid
- [ ] `test_title_required` — без `title` → ValidationError
- [ ] `test_content_required` — без `content` → ValidationError
- [ ] `test_image_url_none_when_no_image` — новость без картинки → `image_url == None`
- [ ] `test_image_url_absolute_when_image_set` — с картинкой → `image_url` начинается с `http://`

---

## Блок 2 — Backend: Staff ViewSet'ы для Events и News

### TICKET-024 — Создать `StaffEventViewSet`

**Файл:** `backend/apps/events/views.py`
**Зависимости:** TICKET-022
**Тест:** TICKET-024-T

#### Технические шаги
- [ ] Добавить импорты в `views.py`:
  ```python
  from rest_framework import viewsets
  from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
  from utils.permissions import IsStaffOrAdmin
  from .serializers import StaffEventSerializer, StaffNewsSerializer
  ```
- [ ] Добавить `StaffEventViewSet(viewsets.ModelViewSet)`:
  - `queryset`: `Event.objects.prefetch_related('reservations').order_by('-date_time')` — все события включая `is_active=False`
  - `serializer_class`: `StaffEventSerializer`
  - `permission_classes`: `[IsAuthenticated, IsStaffOrAdmin]`
  - `parser_classes`: `[MultiPartParser, FormParser, JSONParser]`
  - `pagination_class = None`
- [ ] **Не фильтровать** по `is_active` — staff видит все события
- [ ] Проверить что существующие публичные views не затронуты

#### Тест TICKET-024-T
**Файл:** `backend/apps/events/tests/test_staff_event_views.py`
- [ ] `test_list_requires_auth` — GET без токена → 401
- [ ] `test_list_requires_staff` — GET с токеном обычного пользователя → 403
- [ ] `test_list_includes_inactive` — staff GET → включает события с `is_active=False`
- [ ] `test_create_event_multipart` — POST multipart с изображением → 201, файл обрезан до 16:9
- [ ] `test_create_without_image_returns_400` — POST без `image` → 400 с ключом `image`
- [ ] `test_partial_update_title` — PATCH `{'title': 'Новое'}` → 200
- [ ] `test_partial_update_is_active` — PATCH `{'is_active': False}` → 200
- [ ] `test_partial_update_with_new_image` — PATCH multipart с новым `image` → 200, старый файл удалён (`captureOnCommitCallbacks`)
- [ ] `test_delete_event` — DELETE → 204, объект и файл удалены
- [ ] `test_delete_event_invalidates_cache` — после DELETE версия кэша `events_upcoming` увеличилась

---

### TICKET-025 — Создать `StaffNewsViewSet`

**Файл:** `backend/apps/events/views.py`
**Зависимости:** TICKET-023
**Тест:** TICKET-025-T

#### Технические шаги
- [ ] Добавить `StaffNewsViewSet(viewsets.ModelViewSet)`:
  - `queryset`: `News.objects.all().order_by('-created_at')`
  - `serializer_class`: `StaffNewsSerializer`
  - `permission_classes`: `[IsAuthenticated, IsStaffOrAdmin]`
  - `parser_classes`: `[MultiPartParser, FormParser, JSONParser]`
  - `pagination_class = None`
- [ ] `destroy` наследуется; `django-cleanup` удаляет файл при замене/удалении
- [ ] Убедиться что `NewsListView` (публичный) не затронут

#### Тест TICKET-025-T
**Файл:** `backend/apps/events/tests/test_staff_news_views.py`
- [ ] `test_list_requires_auth` — GET без токена → 401
- [ ] `test_list_requires_staff` — GET с обычным токеном → 403
- [ ] `test_create_news_without_image` — POST `{title, content}` без image → 201
- [ ] `test_create_news_with_image` — POST multipart с image → 201, обложка обрезана до 16:9
- [ ] `test_partial_update_content` — PATCH `{content: 'новый текст'}` → 200
- [ ] `test_add_image_to_existing_news` — PATCH multipart с image на новость без image → 200
- [ ] `test_delete_news_without_image` — DELETE новости без изображения → 204, без ошибки
- [ ] `test_delete_news_with_image` — DELETE → 204, файл удалён (`captureOnCommitCallbacks`)
- [ ] `test_delete_invalidates_cache` — после DELETE версия кэша `events_news` увеличилась

---

## Блок 3 — Backend: URL-маршруты для Events и News Admin

### TICKET-026 — Зарегистрировать URL-маршруты в `events/urls.py`

**Файл:** `backend/apps/events/urls.py`
**Зависимости:** TICKET-024, TICKET-025
**Тест:** интеграционный (TICKET-024-T, TICKET-025-T покрывают)

#### Технические шаги
- [ ] Добавить импорты `DefaultRouter` и viewset'ов:
  ```python
  from rest_framework.routers import DefaultRouter
  from .views import StaffEventViewSet, StaffNewsViewSet
  ```
- [ ] Создать роутер и зарегистрировать:
  ```python
  router = DefaultRouter()
  router.register(r'admin/events', StaffEventViewSet, basename='staff-event')
  router.register(r'admin/news', StaffNewsViewSet, basename='staff-news')
  ```
- [ ] Добавить `path('', include(router.urls))` в `urlpatterns`
- [ ] Проверить что новые пути не конфликтуют с `upcoming/`, `archived/`, `news/`, `reservations/`, `<int:event_id>/photo-report/`
- [ ] Запустить `python manage.py show_urls | grep admin/events` — убедиться что 6 маршрутов зарегистрированы
- [ ] Запустить `python manage.py show_urls | grep admin/news` — аналогично 6 маршрутов

---

## Блок 4 — Backend: Расширить `StaffDishSerializer` для видео

### TICKET-027 — Добавить video-поля в `StaffDishSerializer`

**Файл:** `backend/apps/menu/serializers.py`
**Зависимости:** нет
**Тест:** TICKET-027-T

#### Технические шаги
- [ ] В `StaffDishSerializer` добавить новые поля:
  ```python
  video = serializers.FileField(required=False, allow_null=True, allow_empty_file=False)
  video_url = serializers.SerializerMethodField()
  video_status = serializers.CharField(read_only=True)
  ```
- [ ] Добавить `get_video_url(self, obj)`:
  ```python
  def get_video_url(self, obj):
      if not obj.video_processed:
          return None
      request = self.context.get('request')
      return request.build_absolute_uri(obj.video_processed.url) if request else obj.video_processed.url
  ```
- [ ] Добавить `validate_video(self, value)`: проверить `value.content_type` — допустить `video/mp4`, `video/quicktime`, `video/x-m4v`. При недопустимом типе → `raise ValidationError('Поддерживаются только форматы MP4 и MOV.')`
- [ ] Обновить `Meta.fields`: добавить `'video'`, `'video_url'`, `'video_status'` после `'image_url'`
- [ ] Существующий `validate()` (проверка image на create) — не изменять

#### Тест TICKET-027-T
**Файл:** `backend/apps/menu/tests/test_staff_serializer.py`
- [ ] `test_video_field_is_optional_on_create` — создать блюдо без `video` → valid
- [ ] `test_video_field_accepts_mp4` — `video` с `content_type='video/mp4'` → valid
- [ ] `test_video_field_rejects_text` — `video` с `content_type='text/plain'` → ValidationError с ключом `video`
- [ ] `test_video_status_is_readonly` — передать `video_status='ready'` → значение игнорируется
- [ ] `test_video_url_null_when_not_processed` — блюдо без `video_processed` → `video_url=None`
- [ ] `test_video_url_absolute_when_processed` — блюдо с `video_processed` → `video_url` начинается с `http://`

---

### TICKET-028 — Обновить `StaffDishViewSet` для корректной смены статуса видео

**Файл:** `backend/apps/menu/views.py`
**Зависимости:** TICKET-027
**Тест:** TICKET-028-T

#### Технические шаги
- [ ] В `StaffDishViewSet` добавить `perform_update`:
  ```python
  def perform_update(self, serializer):
      new_video = self.request.FILES.get('video')
      if new_video:
          serializer.save(video_status=Dish.VideoStatus.PENDING)
      else:
          serializer.save()
  ```
  > Причина: если старый `video_status='ready'`, сигнал `trigger_video_processing` не сработает (условие `status not in (PROCESSING, READY)`). Явный сброс в PENDING обходит это.
- [ ] Добавить импорт `Dish` если отсутствует
- [ ] Убедиться что `parser_classes = [MultiPartParser, FormParser, JSONParser]` уже присутствует (не менять)

#### Тест TICKET-028-T
**Файл:** `backend/apps/menu/tests/test_staff_views.py`
- [ ] `test_create_dish_with_video` — POST multipart с `image` + `video` → 201, `video_status='pending'` в ответе
- [ ] `test_create_dish_without_video` — POST только с `image` → 201, `video_status='pending'`
- [ ] `test_partial_update_video_resets_to_pending` — PATCH с новым video на блюдо с `video_status='ready'` → 200, `video_status='pending'`
- [ ] `test_video_status_in_response` — GET detail → ответ содержит `video_status` и `video_url`
- [ ] `test_invalid_video_format_returns_400` — PATCH с файлом `content_type='image/jpeg'` → 400

---

## Блок 5 — Backend: Документация

### TICKET-029 — Обновить `backend/docs/events.md`

**Файл:** `backend/docs/events.md`
**Зависимости:** TICKET-026

#### Технические шаги
- [ ] Добавить секцию `## Admin Events CRUD (Staff Only)` с описанием всех 6 маршрутов `GET/POST /api/v1/events/admin/events/` и `GET/PUT/PATCH/DELETE /api/v1/events/admin/events/{id}/`
- [ ] Указать: Auth `Bearer <access_token>` + `is_staff=true`
- [ ] Указать Content-Type: `multipart/form-data` для create/update с image, `application/json` для PATCH без image
- [ ] Добавить таблицу полей `StaffEventSerializer` (read/write, required/optional)
- [ ] Добавить пример curl для create и PATCH `is_active=false`
- [ ] Описать ошибки: 400 (нет image при create), 403 (не staff), 404 (нет события)
- [ ] Добавить секцию `## Admin News CRUD (Staff Only)` по аналогии — указать что `image` у News опционально
- [ ] Обновить раздел `## Файлы модуля` — добавить новые классы

---

### TICKET-030 — Обновить `backend/docs/menu.md` и `backend/API_FOR_FLUTTER.md`

**Файлы:** `backend/docs/menu.md`, `backend/API_FOR_FLUTTER.md`
**Зависимости:** TICKET-028

#### Технические шаги (menu.md)
- [ ] Обновить таблицу полей `StaffDishSerializer` — добавить строки для `video`, `video_url`, `video_status`
- [ ] Добавить секцию `### Загрузка видео через Staff API` с описанием multipart PATCH и flow статусов: `pending → processing → ready/failed`
- [ ] Добавить временные оценки транскодирования

#### Технические шаги (API_FOR_FLUTTER.md)
- [ ] Добавить подсекцию `### Events & News CRUD` в `## Admin Panel (Staff Only)`
- [ ] Описать flow для `EventEditScreen` и `NewsEditScreen`
- [ ] Добавить подсекцию `### Dish Video Upload` — как Flutter отправляет видео, как читает `video_status`
- [ ] Добавить пример Dio multipart PATCH с видеофайлом

---

## Блок 6 — Flutter: Слой данных для Events и News Admin

### TICKET-031 — Добавить `isActive` в `ApiEvent` и согласовать `PiligrimNewsPost`

**Файл:** `lib/data/models/api_event.dart`, `lib/data/events_news_data.dart`
**Зависимости:** нет
**Тест:** TICKET-031-T

#### Технические шаги (ApiEvent)
- [ ] Добавить `final bool isActive;` в `ApiEvent` с дефолтом `true`
- [ ] Обновить `fromJson`: `isActive: parseBool(json['is_active'] ?? json['isActive'], defaultValue: true)`
- [ ] Обновить `toJson`: добавить `'is_active': isActive`

#### Технические шаги (PiligrimNewsPost)
- [ ] Добавить геттер `int get numericId => int.tryParse(id) ?? 0` — нужен для admin CRUD (deleteNews, updateNews принимают int id)
- [ ] Поля `body` и `publishedAt` уже маппятся через `json['content'] ?? json['body']` и `json['created_at'] ?? json['publishedAt']` — изменений не требуется
- [ ] Запустить `flutter analyze` — убедиться что нет ошибок

#### Тест TICKET-031-T
**Файл:** `test/models/api_event_test.dart`
- [ ] `test_fromJson_includes_is_active_true` — JSON с `is_active: true` → `isActive == true`
- [ ] `test_fromJson_includes_is_active_false` — JSON с `is_active: false` → `isActive == false`
- [ ] `test_fromJson_is_active_defaults_to_true` — JSON без `is_active` → `isActive == true`
- [ ] `test_news_numeric_id_parsed` — `PiligrimNewsPost.fromJson({'id': 5, ...})` → `numericId == 5`

---

### TICKET-032 — Добавить Admin CRUD методы в `EventsRepository`

**Файл:** `lib/data/repositories/events_repository.dart`
**Зависимости:** TICKET-026, TICKET-031
**Тест:** TICKET-032-T

#### Технические шаги
- [ ] Добавить `fetchAdminEvents()` — GET `/events/admin/events/`, возвращает `List<ApiEvent>` (без пагинации — `pagination_class = None`):
  ```dart
  Future<List<ApiEvent>> fetchAdminEvents() async {
    final response = await _dio.get<List<dynamic>>('/events/admin/events/');
    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => ApiEvent.fromJson(json,
            isPast: DateTime.tryParse(json['date_time']?.toString() ?? '')
                    ?.isBefore(DateTime.now()) == true))
        .toList();
  }
  ```
- [ ] Добавить `createEvent(Map<String, dynamic> fields, {File? image})` — POST multipart на `/events/admin/events/`
- [ ] Добавить `updateEvent(int id, Map<String, dynamic> fields, {File? image})` — с image → PATCH multipart; без image → PATCH JSON
- [ ] Добавить `deleteEvent(int id)` — DELETE `/events/admin/events/$id/`
- [ ] Добавить `fetchAdminNews()` — GET `/events/admin/news/`, возвращает `List<PiligrimNewsPost>`
- [ ] Добавить `createNews(Map<String, dynamic> fields, {File? image})` — POST multipart
- [ ] Добавить `updateNews(int id, Map<String, dynamic> fields, {File? image})` — PATCH
- [ ] Добавить `deleteNews(int id)` — DELETE `/events/admin/news/$id/`
- [ ] Для `date_time` использовать `DateTime.toUtc().toIso8601String()` при отправке

#### Тест TICKET-032-T
**Файл:** `test/repositories/events_repository_test.dart`
- [ ] `test_fetchAdminEvents_returns_list` — мок Dio 200 с массивом → список `ApiEvent` включая `isActive=false`
- [ ] `test_createEvent_sends_multipart` — mock Dio.post → FormData отправлен с `image`
- [ ] `test_createEvent_without_image_sends_formdata` — без image → FormData без ключа `image`
- [ ] `test_updateEvent_with_image_sends_multipart` — PATCH с image → FormData
- [ ] `test_updateEvent_without_image_sends_json` — PATCH без image → JSON body
- [ ] `test_deleteEvent_calls_delete_url` — `deleteEvent(5)` → DELETE на `/events/admin/events/5/`
- [ ] `test_fetchAdminNews_returns_list` — мок → список `PiligrimNewsPost`
- [ ] `test_createNews_without_image_sends_formdata` — POST без image → FormData (сервер допускает)
- [ ] `test_deleteNews_calls_delete_url` — `deleteNews(3)` → DELETE на `/events/admin/news/3/`

---

## Блок 7 — Flutter: Admin UI на `EventsScreen`

### TICKET-033 — Admin pencil overlay на `_EventListCard` и `_NewsCard`

**Файл:** `lib/screens/events_screen.dart`
**Зависимости:** TICKET-031
**Тест:** TICKET-033-T

#### Технические шаги
- [ ] В `_EventListCard` добавить `required this.isAdmin` в конструктор
- [ ] Внутри `Stack` карточки, после существующих виджетов, добавить:
  ```dart
  if (isAdmin)
    Positioned(
      top: 8, right: 8,
      child: _AdminEditButton(onTap: () => _openEventEdit(context, event)),
    ),
  ```
- [ ] В `_NewsCard` добавить `required this.isAdmin` и аналогичный overlay
- [ ] Создать `_AdminEditButton` — круглая кнопка 36×36:
  - фон: `PiligrimColors.earthDeep.withValues(alpha: 0.88)`
  - иконка: `Icons.edit_outlined`, `PiligrimColors.water`, size 16
  - `PiligrimTap` для haptic feedback
  - border: `PiligrimColors.water.withValues(alpha: 0.35)`, width 0.8
- [ ] В `_EventsScreenState.build()` читать `final isAdmin = context.watch<AuthProvider>().isAdmin`
- [ ] Передавать `isAdmin` во все `_EventListCard` и `_NewsCard`
- [ ] Убедиться что без флага кнопка физически отсутствует в дереве (не invisible)

#### Тест TICKET-033-T
**Файл:** `test/widgets/event_list_card_test.dart`
- [ ] `test_admin_button_visible_when_is_admin` — `isAdmin=true` → `_AdminEditButton` в дереве
- [ ] `test_admin_button_absent_for_regular_user` — `isAdmin=false` → кнопки нет
- [ ] `test_news_card_admin_button_visible` — `_NewsCard(isAdmin: true)` → кнопка есть

---

### TICKET-034 — FAB «Добавить» на `EventsScreen`

**Файл:** `lib/screens/events_screen.dart`
**Зависимости:** TICKET-033
**Тест:** TICKET-034-T

#### Технические шаги
- [ ] Добавить `floatingActionButton` в `Scaffold`:
  ```dart
  floatingActionButton: context.watch<AuthProvider>().isAdmin
    ? FloatingActionButton(
        backgroundColor: PiligrimColors.earthWarm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: PiligrimColors.water.withValues(alpha: 0.35)),
        ),
        child: Icon(Icons.add, color: PiligrimColors.water),
        onPressed: () {
          if (_view == _AfichaView.events) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const EventEditScreen(event: null),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NewsEditScreen(news: null),
            ));
          }
        },
      )
    : null,
  ```
- [ ] FAB в режиме `_AfichaView.events` → открывает `EventEditScreen(event: null)`
- [ ] FAB в режиме `_AfichaView.news` → открывает `NewsEditScreen(news: null)`

#### Тест TICKET-034-T
- [ ] `test_fab_visible_for_admin` — admin → FAB в дереве
- [ ] `test_fab_hidden_for_regular_user` — обычный пользователь → FAB отсутствует
- [ ] `test_fab_opens_event_edit_in_events_view` — admin + `_AfichaView.events`, тап FAB → Navigator push с `EventEditScreen`
- [ ] `test_fab_opens_news_edit_in_news_view` — admin + `_AfichaView.news`, тап FAB → Navigator push с `NewsEditScreen`

---

## Блок 8 — Flutter: EventEditScreen

### TICKET-035 — Скелет `EventEditScreen` (форма без отправки)

**Файл:** `lib/screens/event_edit_screen.dart` (новый файл)
**Зависимости:** TICKET-031
**Тест:** TICKET-035-T

#### Технические шаги
- [ ] Создать `EventEditScreen(StatefulWidget)`:
  ```dart
  final ApiEvent? event;  // null = режим создания
  ```
- [ ] Инициализировать в `initState`:
  - `_titleCtrl` ← `event?.title ?? ''`
  - `_descriptionCtrl` ← `event?.description ?? ''`
  - `_priceCtrl` ← `event?.priceFrom?.toString() ?? ''`
  - `_selectedDateTime` — `DateTime?`, ← `event?.startsAt`
  - `_selectedFormat` — `ApiEventFormat`, ← `event?.format ?? ApiEventFormat.open`
  - `_maxPlaces` — `int`, ← `event?.maxPlaces ?? 0`
  - `_isActive` — `bool`, ← `event?.isActive ?? true`
- [ ] Форма:
  - Поле даты/времени: `TextFormField` только для чтения + `onTap` → `showDatePicker` затем `showTimePicker`
  - `DropdownButtonFormField<ApiEventFormat>` — «Открытое» / «Закрытое»
  - Поле цены (optional) с hint `'Оставьте пустым для свободного входа'`
  - Поле `max_places` с `keyboardType: TextInputType.number`; hint `'0 — без ограничений'`
  - `Switch.adaptive` для `is_active`
- [ ] AppBar: «Назад» + delete icon при edit-mode (`PiligrimColors.fruit`)
- [ ] Дизайн — полностью идентичен `DishEditScreen`: `_buildFieldLabel`, `_buildInput`, цвета `PiligrimColors`
- [ ] **Без отправки** — `_save()` только debugPrint данных

#### Тест TICKET-035-T
**Файл:** `test/widgets/event_edit_screen_test.dart`
- [ ] `test_renders_in_create_mode` — `event=null` → поля пустые, нет иконки удаления
- [ ] `test_renders_in_edit_mode` — `event=someEvent` → поля заполнены, иконка удаления есть
- [ ] `test_validation_title_required` — submit без title → ошибка валидации
- [ ] `test_format_dropdown_has_two_options` — два варианта: Открытое, Закрытое

---

### TICKET-036 — Image picker + preview в `EventEditScreen`

**Файл:** `lib/screens/event_edit_screen.dart`
**Зависимости:** TICKET-035
**Тест:** ручной (платформо-зависимый)

#### Технические шаги
- [ ] Добавить `File? _localImageFile` в state
- [ ] Реализовать `_pickAndCropImage()` — идентично `DishEditScreen._pickAndCropImage()`:
  - `ImagePicker().pickImage(source: ImageSource.gallery)`
  - `ImageCropper().cropImage(aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9), lockAspectRatio: true)`
  - Те же `AndroidUiSettings` / `IOSUiSettings`
- [ ] Добавить `_EventPreviewCard` (аналог `_DishPreviewCard`):
  - `AspectRatio(16/9)` — `Image.file` или `CachedNetworkImage(event!.coverUrl)` или placeholder `Icons.event_outlined`
  - Нижний градиент + title из `_titleCtrl.text`
  - Дата-badge из `_selectedDateTime`
- [ ] Кнопка «Выбрать фото» — идентична `DishEditScreen._buildImageSection()`

---

### TICKET-037 — Сохранение и удаление события

**Файл:** `lib/screens/event_edit_screen.dart`
**Зависимости:** TICKET-032, TICKET-035
**Тест:** TICKET-037-T

#### Технические шаги
- [ ] Реализовать `_save()`:
  ```dart
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isSaving = true);
  try {
    final fields = {
      'title': _titleCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'date_time': _selectedDateTime!.toUtc().toIso8601String(),
      'format': _selectedFormat.name,
      'price': _priceCtrl.text.trim().isEmpty ? null : _priceCtrl.text.trim(),
      'max_places': _maxPlaces,
      'is_active': _isActive,
    };
    widget.event == null
        ? await _repo.createEvent(fields, image: _localImageFile)
        : await _repo.updateEvent(widget.event!.id, fields, image: _localImageFile);
    if (mounted) context.read<EventsProvider>().load();
    if (mounted) Navigator.of(context).pop();
  } on DioException catch (e) {
    // Парсить e.response?.data как Map, показывать поля ошибок в SnackBar
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
  ```
- [ ] Кнопка «Опубликовать» — `PiligrimColors.steppe` gradient + `PiligrimLoader` при `_isSaving`
- [ ] Реализовать `_deleteEvent()` с `showDialog` — идентично `DishEditScreen._deleteDish()`

#### Тест TICKET-037-T
- [ ] `test_save_calls_createEvent_in_create_mode` — mock repo → `createEvent` вызван
- [ ] `test_save_calls_updateEvent_in_edit_mode` — mock repo → `updateEvent(id, ...)` вызван
- [ ] `test_save_disabled_while_saving` — при `_isSaving` кнопка отсутствует, отображается `PiligrimLoader`
- [ ] `test_delete_shows_confirmation_dialog` — тап корзины → dialog
- [ ] `test_delete_confirmed_calls_deleteEvent` — подтверждение → `deleteEvent` вызван с правильным id

---

## Блок 9 — Flutter: NewsEditScreen

### TICKET-038 — Создать `NewsEditScreen`

**Файл:** `lib/screens/news_edit_screen.dart` (новый файл)
**Зависимости:** TICKET-032
**Тест:** TICKET-038-T

#### Технические шаги
- [ ] Создать `NewsEditScreen(StatefulWidget)`:
  ```dart
  final PiligrimNewsPost? news;  // null = режим создания
  ```
- [ ] Инициализировать в `initState`:
  - `_titleCtrl` ← `news?.title ?? ''`
  - `_contentCtrl` ← `news?.body ?? ''`
  - `_localImageFile = null`
- [ ] Форма:
  - Поле «Заголовок» (required validator)
  - Поле «Текст новости» (required validator, `maxLines: 6`)
  - Секция изображения — идентично `EventEditScreen`, 16:9, lockAspectRatio
  - Preview: `Image.file` → `CachedNetworkImage(news!.imageUrl)` → placeholder `Icons.article_outlined`
  - **Без** `Switch is_active` — у `News` нет этого поля
- [ ] AppBar: «Назад» + delete icon при edit-mode
- [ ] `_save()`:
  ```dart
  final fields = {'title': _titleCtrl.text.trim(), 'content': _contentCtrl.text.trim()};
  news == null
      ? await _repo.createNews(fields, image: _localImageFile)
      : await _repo.updateNews(news!.numericId, fields, image: _localImageFile);
  context.read<EventsProvider>().loadNews();
  Navigator.of(context).pop();
  ```
- [ ] `_deleteNews()` с confirm dialog → `await _repo.deleteNews(news!.numericId)` → pop
- [ ] Обработка `DioException` — идентично другим edit экранам

#### Тест TICKET-038-T
**Файл:** `test/widgets/news_edit_screen_test.dart`
- [ ] `test_renders_in_create_mode` — `news=null` → поля пустые, нет иконки удаления
- [ ] `test_renders_in_edit_mode` — `news=someNews` → title и content заполнены, есть иконка удаления
- [ ] `test_validation_title_required` — submit без title → error
- [ ] `test_validation_content_required` — submit без content → error
- [ ] `test_save_calls_createNews_in_create_mode` — mock repo → `createNews` вызван
- [ ] `test_save_calls_updateNews_in_edit_mode` — mock repo → `updateNews(numericId, ...)` вызван
- [ ] `test_delete_confirmed_calls_deleteNews` — confirm dialog → `deleteNews` вызван

---

## Блок 10 — Flutter: Видео-загрузка в DishEditScreen

### TICKET-039 — Проверить поддержку video в `image_picker` и нативные разрешения

**Файлы:** `pubspec.yaml`, `ios/Runner/Info.plist`
**Зависимости:** нет
**Тест:** ручной

#### Технические шаги
- [ ] Проверить: `ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: 5))` доступен в `image_picker: ^1.1.2` — если да, новый пакет не нужен
- [ ] **iOS** — добавить в `ios/Runner/Info.plist` если ещё нет:
  ```xml
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>Выберите вертикальное видео блюда из галереи</string>
  ```
- [ ] **Android** — дополнительных разрешений не требуется
- [ ] Запустить `flutter pub get` — убедиться что нет конфликтов

---

### TICKET-040 — Добавить video-секцию в `DishEditScreen`

**Файл:** `lib/screens/dish_edit_screen.dart`
**Зависимости:** TICKET-027, TICKET-039
**Тест:** TICKET-040-T

#### Технические шаги
- [ ] Добавить `File? _localVideoFile` в state
- [ ] Реализовать `_pickVideo()`:
  ```dart
  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) setState(() => _localVideoFile = File(picked.path));
  }
  ```
- [ ] Добавить `_buildVideoSection()` после `_buildImageSection()`:
  - Заголовок: `_buildFieldLabel('ВИДЕО ДЛЯ ЛЕНТЫ (9:16)')`
  - Если `_localVideoFile != null` → имя файла + `Icons.check_circle_outline` (`PiligrimColors.water`)
  - Если `widget.dish?.videoUrl != null` → `_buildVideoStatusBadge()`
  - Кнопка «Выбрать видео» — стиль аналогичен «Выбрать фото», иконка `Icons.video_library_outlined`
  - Hint: `'Вертикальное видео 9:16. Транскодирование занимает 1–5 минут.'`
- [ ] Реализовать `_buildVideoStatusBadge()`:
  ```dart
  final (label, color) = switch (widget.dish?.videoStatus ?? 'pending') {
    'ready'      => ('ГОТОВО',         PiligrimColors.water),
    'processing' => ('ОБРАБАТЫВАЕТСЯ', PiligrimColors.steppe),
    'failed'     => ('ОШИБКА',         PiligrimColors.fruit),
    _            => ('ОЖИДАЕТ',        PiligrimColors.sky.withValues(alpha: 0.45)),
  };
  ```
- [ ] Обновить вызовы `_repo.createDish` / `_repo.updateDish` в `_save()` — передать `video: _localVideoFile`

#### Тест TICKET-040-T
**Файл:** `test/widgets/dish_edit_screen_test.dart`
- [ ] `test_video_section_shows_ready_badge` — `dish.videoStatus='ready'` → badge «ГОТОВО»
- [ ] `test_video_section_shows_pending_badge` — `videoStatus='pending'` → badge «ОЖИДАЕТ»
- [ ] `test_video_section_shows_failed_badge` — `videoStatus='failed'` → badge «ОШИБКА», цвет `PiligrimColors.fruit`
- [ ] `test_video_section_shows_local_file_after_pick` — после `_pickVideo()` → имя файла отображается
- [ ] `test_save_passes_video_to_createDish` — mock repo, submit с `_localVideoFile != null` → `createDish` вызван с `video:` параметром

---

### TICKET-041 — Обновить `MenuRepository` для передачи видео

**Файл:** `lib/data/repositories/menu_repository.dart`
**Зависимости:** TICKET-027
**Тест:** TICKET-041-T

#### Технические шаги
- [ ] Обновить сигнатуру `createDish`:
  ```dart
  Future<ApiDish> createDish(
    Map<String, dynamic> fields, {
    File? image,
    File? video,
  }) async { ... }
  ```
- [ ] В `_buildFormData` добавить видео:
  ```dart
  if (video != null) {
    map['video'] = await MultipartFile.fromFile(
      video.path,
      filename: 'dish_video.mp4',
      contentType: DioMediaType('video', 'mp4'),
    );
  }
  ```
- [ ] При `video != null` всегда отправлять multipart (даже если `image == null`)
- [ ] Обновить `updateDish` аналогично — добавить `File? video`
- [ ] Убедиться что `video` передаётся как отдельный параметр, а не в `fields` (чтобы не конфликтовать с `_encodeListFields`)

#### Тест TICKET-041-T
**Файл:** `test/repositories/menu_repository_test.dart`
- [ ] `test_createDish_with_video_sends_multipart` — вызов с `video: File(...)` → FormData содержит ключ `video`
- [ ] `test_createDish_without_video_sends_multipart_without_video_key` — без video → FormData без `video`
- [ ] `test_updateDish_with_video_returns_pending_status` — mock возвращает `video_status: pending` → `ApiDish.videoStatus == 'pending'`

---

## Блок 11 — Сквозное тестирование

### TICKET-042 — Integration test: полный flow создания события

**Файл:** `test/integration/admin_create_event_test.dart`
**Зависимости:** все тикеты Блоков 1–9

#### Технические шаги
- [ ] `docker compose up` — поднять бэкенд
- [ ] Войти как staff → `AuthProvider.isAdmin == true`
- [ ] `EventsScreen`: FAB присутствует, pencil-overlay на карточках присутствует
- [ ] FAB (events view) → `EventEditScreen(event: null)` — поля пустые
- [ ] Заполнить форму, выбрать фото → «Опубликовать» → POST → 201
- [ ] Вернуться на `EventsScreen` → новое событие в списке
- [ ] Pencil → `EventEditScreen` с заполненными полями → изменить title → 200
- [ ] Корзина → диалог → подтвердить → событие исчезло
- [ ] GET `/api/v1/events/admin/events/` с обычным токеном → 403

---

### TICKET-043 — Integration test: загрузка видео к блюду

**Файл:** `test/integration/admin_dish_video_test.dart`
**Зависимости:** TICKET-040, TICKET-041

#### Технические шаги
- [ ] Войти как staff → `MenuScreen` → pencil на блюде → `DishEditScreen`
- [ ] Секция «ВИДЕО ДЛЯ ЛЕНТЫ (9:16)» присутствует
- [ ] Выбрать видео → имя файла отображается → «Сохранить» → PATCH с видео → `video_status='pending'`
- [ ] Повторно открыть экран → badge «ОЖИДАЕТ» или «ОБРАБАТЫВАЕТСЯ»
- [ ] После завершения Celery → badge «ГОТОВО»
- [ ] Загрузить новое видео → badge снова «ОЖИДАЕТ»

---

### TICKET-044 — Smoke test: обычный пользователь не видит admin UI на EventsScreen

**Зависимости:** TICKET-033, TICKET-034

#### Технические шаги
- [ ] Войти как обычный пользователь
- [ ] `EventsScreen`: FAB отсутствует, pencil-overlay отсутствует на событиях и новостях
- [ ] POST `/api/v1/events/admin/events/` с обычным токеном → 403
- [ ] POST `/api/v1/events/admin/news/` с обычным токеном → 403

---

## Зависимости между тикетами (граф)

```
Feature 1: Events/News Admin
─────────────────────────────
TICKET-022 ──► TICKET-024 ──► TICKET-026 ──► TICKET-029 ──► TICKET-030
TICKET-023 ──► TICKET-025 ──► TICKET-026
TICKET-026 ──────────────────────────────► TICKET-032
TICKET-031 ──► TICKET-032 ──► TICKET-037 ──► TICKET-042
TICKET-031 ──► TICKET-035 ──► TICKET-036 ──► TICKET-037
TICKET-032 ──────────────────────────────► TICKET-038
TICKET-033 ──► TICKET-034 ──► TICKET-042
TICKET-033 ──► TICKET-044

Feature 2: Dish Video
─────────────────────
TICKET-027 ──► TICKET-028 ──► TICKET-030
TICKET-027 ──► TICKET-041 ──► TICKET-040 ──► TICKET-043
TICKET-039 ──► TICKET-040
TICKET-028 ──► TICKET-043
```

---

## Оценка сложности и времени

| Блок | Тикеты | Время |
|---|---|---|
| Backend: Staff сериализаторы Events/News | 022, 023 | 1 ч |
| Backend: Staff ViewSet'ы Events/News | 024, 025 | 1.5 ч |
| Backend: URL-маршруты Events/News | 026 | 20 мин |
| Backend: Video в StaffDishSerializer | 027, 028 | 1.5 ч |
| Backend: Документация | 029, 030 | 1 ч |
| Flutter: Модели ApiEvent + PiligrimNewsPost | 031 | 30 мин |
| Flutter: EventsRepository admin методы | 032 | 1.5 ч |
| Flutter: Admin UI на EventsScreen | 033, 034 | 1.5 ч |
| Flutter: EventEditScreen | 035, 036, 037 | 3.5 ч |
| Flutter: NewsEditScreen | 038 | 2 ч |
| Flutter: video_picker setup | 039 | 20 мин |
| Flutter: VideoSection в DishEditScreen | 040 | 2 ч |
| Flutter: MenuRepository video support | 041 | 45 мин |
| Тесты backend | 022-T — 028-T | 2.5 ч |
| Тесты Flutter | 031-T — 041-T | 2 ч |
| Сквозное тестирование | 042, 043, 044 | 1.5 ч |
| **Итого** | **23 тикета** | **~23 ч (~3 рабочих дня)** |

---

## Ключевые риски

| Риск | Вероятность | Митигация |
|---|---|---|
| `events/urls.py` использует `urlpatterns = [...]` без router — конфликт при добавлении `include(router.urls)` | Низкая | Добавить `path('', include(router.urls))` как отдельную запись после существующих `path()` |
| `image_picker.pickVideo()` не поддерживает `maxDuration` в v1.1.2 | Низкая | Проверить changelog перед TICKET-039; при отсутствии — убрать ограничение длины |
| `StaffDishViewSet.perform_update` нужен для сброса `video_status` при обновлении видео | Обработан | TICKET-028: явный `video_status=PENDING` при наличии нового файла в `perform_update` |
| `PiligrimNewsPost.numericId` — геттер из String → коллизии если `id` не числовой | Средняя | `int.tryParse(id) ?? 0` — безопасно, бэкенд всегда возвращает числовой ID |
| Django `DATA_UPLOAD_MAX_MEMORY_SIZE` ограничивает размер загружаемых видео | Средняя | Проверить `settings.py` — добавить `DATA_UPLOAD_MAX_MEMORY_SIZE = 200 * 1024 * 1024` если нужно |
| Cache invalidation для Events после admin CRUD | Нет риска | Существующие signals в `events/signals.py` уже слушают `post_save`/`post_delete` на уровне модели |

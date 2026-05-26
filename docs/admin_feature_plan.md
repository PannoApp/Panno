# Проект: Реализация административного функционала внутри приложения

**Статус:** Планирование  
**Стек:** Django REST Framework + Flutter  
**Scope MVP:** CRUD для блюд (Dish). События, новости, интерьер — следующий спринт.  
**Принцип:** один тикет = одна изолированная задача, покрытая тестом.

---

## Контекст

Администраторы ресторана управляют контентом (блюдами, фото) прямо из клиентского Flutter-приложения. Никаких отдельных приложений. Функционал скрыт за флагом `is_staff` — обычные пользователи не видят никаких изменений в UI.

Что уже есть и **не нужно пересоздавать:**
- `User.role` (admin / hall_manager / content_manager) + `is_staff` автосинхронизируется в `User.save()`
- `AutoCropImageMixin` в `backend/utils/image_processing.py` — центро-кроп, 1200px, JPEG 85%
- `upload_paths.py` с UUID-путями для медиафайлов
- `django-cleanup` авто-удаляет файлы при замене/удалении объекта
- Pillow 10.3.0 в requirements

---

## Блок 1 — Backend: Ролевая модель и авторизация

### TICKET-001 — Добавить `is_staff` и `role` в ответ API профиля

**Файл:** `backend/apps/users/serializers.py`  
**Зависимости:** нет  
**Тест:** TICKET-001-T

#### Технические шаги
- [ ] Открыть `UserProfileSerializer`, найти `Meta.fields`
- [ ] Добавить `'is_staff'` и `'role'` в конец кортежа `fields`
- [ ] Добавить оба поля в `read_only_fields` (клиент не может их менять)
- [ ] Убедиться что `role` возвращает пустую строку `""` для обычных пользователей (не `null`)
- [ ] Запустить `GET /api/v1/users/profile/` с токеном staff-пользователя — проверить наличие полей в ответе
- [ ] Запустить `GET /api/v1/users/profile/` с токеном обычного пользователя — убедиться что `is_staff: false`, `role: ""`

#### Тест TICKET-001-T
**Файл:** `backend/apps/users/tests/test_serializers.py`
- [ ] `test_profile_response_includes_is_staff` — staff-пользователь: `is_staff=true` в ответе
- [ ] `test_profile_response_includes_role` — staff-пользователь с ролью `admin`: `role="admin"` в ответе
- [ ] `test_profile_response_regular_user` — обычный пользователь: `is_staff=false`, `role=""` в ответе
- [ ] `test_profile_role_readonly` — PATCH с `role="admin"` игнорируется

---

### TICKET-002 — Создать permission class `IsStaffOrAdmin`

**Файл:** `backend/utils/permissions.py` (новый файл)  
**Зависимости:** нет  
**Тест:** TICKET-002-T

#### Технические шаги
- [ ] Создать файл `backend/utils/permissions.py`
- [ ] Реализовать `IsStaffOrAdmin(BasePermission)`:
  - `has_permission`: `user.is_authenticated and user.is_staff`
- [ ] **Не использовать** DRF's `IsAdminUser` — он также требует `is_superuser` в некоторых версиях
- [ ] Убедиться что `AnonymousUser` корректно отклоняется (не падает с AttributeError)

#### Тест TICKET-002-T
**Файл:** `backend/utils/tests/test_permissions.py`
- [ ] `test_staff_user_allowed` — `is_staff=True` → permission granted
- [ ] `test_regular_user_denied` — `is_staff=False` → 403
- [ ] `test_anonymous_denied` — неаутентифицированный → 403
- [ ] `test_superuser_allowed` — `is_superuser=True` (у него всегда `is_staff=True`) → granted

---

## Блок 2 — Backend: Write API для блюд

### TICKET-003 — Создать `StaffDishSerializer` (write-capable)

**Файл:** `backend/apps/menu/serializers.py`  
**Зависимости:** нет  
**Тест:** TICKET-003-T

#### Технические шаги
- [ ] Добавить `StaffDishSerializer(ModelSerializer)` в конец файла, **не трогая** существующий `DishSerializer`
- [ ] Поля:
  - `category` → `PrimaryKeyRelatedField(queryset=Category.objects.all())`
  - `tags` → `PrimaryKeyRelatedField(many=True, required=False)`
  - `allergens` → `PrimaryKeyRelatedField(many=True, required=False)`
  - `image` → `ImageField(required=False)` — multipart
  - `image_url` → `SerializerMethodField` возвращает абсолютный URL через `request.build_absolute_uri()`
  - `is_active`, `name`, `description`, `price`, `weight`, `story`
- [ ] В `validate()` добавить проверку: при создании (no `self.instance`) и `image` отсутствует → `raise ValidationError`
- [ ] `video` и `video_processed` — **исключить** из MVP
- [ ] Убедиться что `AutoCropImageMixin` в `Dish.save()` срабатывает автоматически (тестировать через viewset)

#### Тест TICKET-003-T
**Файл:** `backend/apps/menu/tests/test_staff_serializer.py`
- [ ] `test_valid_create_data` — валидные данные с изображением → valid
- [ ] `test_create_without_image_invalid` — без image на create → ValidationError
- [ ] `test_partial_update_without_image_valid` — PATCH без image → valid
- [ ] `test_category_accepts_int_id` — передать `category=1` (int) → корректно маппится
- [ ] `test_image_url_is_absolute` — `image_url` начинается с `http://`

---

### TICKET-004 — Создать `StaffDishViewSet`

**Файл:** `backend/apps/menu/views.py`  
**Зависимости:** TICKET-002, TICKET-003  
**Тест:** TICKET-004-T

#### Технические шаги
- [ ] Добавить `StaffDishViewSet(ModelViewSet)` в конец `views.py`:
  - `queryset`: `Dish.objects.select_related('category').prefetch_related('tags', 'allergens').order_by('category__order', 'id')`
  - `serializer_class`: `StaffDishSerializer`
  - `permission_classes`: `[IsAuthenticated, IsStaffOrAdmin]`
  - `parser_classes`: `[MultiPartParser, FormParser, JSONParser]`
  - `pagination_class = None` (админу нужен полный список без пагинации)
- [ ] **Не фильтровать** по `is_active` — staff видит все блюда включая неактивные
- [ ] Убедиться что `destroy` работает + `django-cleanup` удаляет файл
- [ ] Проверить что существующий `DishListView` не затронут

#### Тест TICKET-004-T
**Файл:** `backend/apps/menu/tests/test_staff_views.py`
- [ ] `test_list_requires_staff` — GET без аутентификации → 401
- [ ] `test_list_requires_staff_role` — GET с обычным токеном → 403
- [ ] `test_list_includes_inactive` — staff GET → включает блюда с `is_active=False`
- [ ] `test_create_dish_multipart` — POST multipart с изображением → 201, image обрезан
- [ ] `test_create_without_image_returns_400` — POST без image → 400
- [ ] `test_partial_update_name` — PATCH `{name: "новое"}` → 200
- [ ] `test_partial_update_with_new_image` — PATCH multipart с новым image → 200, старый файл удалён
- [ ] `test_delete_dish` — DELETE → 204, файл удалён с диска

---

### TICKET-005 — Зарегистрировать URL-маршруты

**Файл:** `backend/apps/menu/urls.py`  
**Зависимости:** TICKET-004  
**Тест:** интеграционный (TICKET-004-T покрывает)

#### Технические шаги
- [ ] Создать `DefaultRouter()` в `urls.py` (если ещё нет)
- [ ] Зарегистрировать: `router.register(r'admin/dishes', StaffDishViewSet, basename='staff-dish')`
- [ ] Добавить `router.urls` в `urlpatterns`
- [ ] Проверить что новые пути не конфликтуют с существующими (`dishes/`, `categories/`, `tags/`)
- [ ] Запустить `python manage.py show_urls | grep admin/dishes` — убедиться что 6 маршрутов зарегистрированы

---

### TICKET-006 — Добавить endpoint для списка аллергенов

**Файлы:** `backend/apps/menu/views.py`, `backend/apps/menu/urls.py`  
**Зависимости:** TICKET-005  
**Тест:** TICKET-006-T

> **Зачем:** `DishEditScreen` во Flutter нужен список аллергенов для формы. Публичный endpoint, аналог `TagListView`.

#### Технические шаги
- [ ] Добавить `AllergenListView(ListAPIView)`:
  - `serializer_class = AllergenSerializer`
  - `permission_classes = [AllowAny]`
  - `queryset = Allergen.objects.all().order_by('name')`
- [ ] Добавить URL: `path('allergens/', AllergenListView.as_view(), name='allergen-list')`
- [ ] Проверить `GET /api/v1/menu/allergens/` — возвращает список

#### Тест TICKET-006-T
- [ ] `test_allergen_list_public` — GET без токена → 200
- [ ] `test_allergen_list_returns_all` — все аллергены в ответе
- [ ] `test_allergen_list_sorted_by_name` — сортировка по имени

---

## Блок 3 — Backend: Документация

### TICKET-007 — Обновить `backend/docs/menu.md`

**Файл:** `backend/docs/menu.md`  
**Зависимости:** TICKET-005, TICKET-006

#### Технические шаги
- [ ] Добавить секцию `## Admin Dish CRUD (Staff Only)`
- [ ] Описать все 6 маршрутов (`GET`, `POST`, `GET/{id}`, `PUT/{id}`, `PATCH/{id}`, `DELETE/{id}`)
- [ ] Указать: Auth: `Bearer <access_token>` + `is_staff=true`
- [ ] Указать: Content-Type `multipart/form-data` для create/update с image, `application/json` для PATCH без image
- [ ] Добавить таблицу полей `StaffDishSerializer` (read/write, required/optional)
- [ ] Добавить пример curl для create и partial update
- [ ] Добавить описание ошибок: 400 (нет image при create), 403 (не staff), 404 (нет блюда)
- [ ] Добавить секцию `## Allergens` с описанием `GET /api/v1/menu/allergens/`

---

### TICKET-008 — Обновить `backend/API_FOR_FLUTTER.md`

**Файл:** `backend/API_FOR_FLUTTER.md`  
**Зависимости:** TICKET-007

#### Технические шаги
- [ ] Добавить секцию `## Admin Panel (Staff Only)`
- [ ] Описать flow: проверка `is_staff` из `/users/profile/` → условный показ admin UI
- [ ] Добавить примеры Dio-запросов (multipart FormData) для create, update, delete
- [ ] Указать что при PATCH без image отправлять `application/json` (не multipart)
- [ ] Добавить endpoint `GET /api/v1/menu/allergens/`
- [ ] Описать поведение `AutoCropImageMixin`: загружать в любом формате — бэкенд вернёт обрезанный JPEG

---

## Блок 4 — Flutter: Ролевая модель на клиенте

### TICKET-009 — Добавить `isStaff` и `role` в `UserProfile`

**Файл:** `lib/data/models/user_profile.dart`  
**Зависимости:** TICKET-001 (бэкенд должен возвращать поля)  
**Тест:** TICKET-009-T

#### Технические шаги
- [ ] Добавить два поля в `UserProfile`:
  ```dart
  final bool isStaff;
  final String role;
  ```
- [ ] Добавить convenience getter: `bool get isAdmin => isStaff;`
- [ ] Обновить `fromJson`:
  - `isStaff: json['is_staff'] as bool? ?? false`
  - `role: json['role'] as String? ?? ''`
- [ ] Обновить `toJson`, `copyWith`
- [ ] Сделать оба параметра **опциональными с дефолтами** (`isStaff = false`, `role = ''`) — чтобы не сломать существующие конструкторы в тестах
- [ ] Запустить `flutter analyze` — убедиться что нет ошибок

#### Тест TICKET-009-T
**Файл:** `test/models/user_profile_test.dart`
- [ ] `test_fromJson_with_is_staff_true` — `{is_staff: true, role: "admin"}` → `isStaff=true`, `isAdmin=true`
- [ ] `test_fromJson_regular_user` — `{is_staff: false, role: ""}` → `isAdmin=false`
- [ ] `test_fromJson_missing_fields` — JSON без `is_staff`/`role` → дефолты, без краша
- [ ] `test_copyWith_preserves_is_staff` — `copyWith(firstName: "X")` не сбрасывает `isStaff`

---

### TICKET-010 — Добавить `isAdmin` геттер в `AuthProvider`

**Файл:** `lib/providers/auth_provider.dart`  
**Зависимости:** TICKET-009

#### Технические шаги
- [ ] Добавить публичный геттер:
  ```dart
  bool get isAdmin => currentUser?.isAdmin ?? false;
  ```
- [ ] Убедиться что при логауте `currentUser = null` → `isAdmin` корректно возвращает `false`
- [ ] `_loadProfile()` уже десериализует профиль через репозиторий — новые поля подхватятся без изменений
- [ ] Запустить `flutter analyze`

---

## Блок 5 — Flutter: Пакеты и нативная конфигурация

### TICKET-011 — Добавить `image_picker` и `image_cropper`

**Файлы:** `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`  
**Зависимости:** нет  
**Тест:** ручной (платформо-зависимый)

#### Технические шаги
- [ ] Добавить в `pubspec.yaml` раздел `dependencies`:
  ```yaml
  image_picker: ^1.1.2
  image_cropper: ^8.0.2
  ```
- [ ] Запустить `flutter pub get` — убедиться что нет конфликтов версий
- [ ] **iOS** — добавить в `ios/Runner/Info.plist`:
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Выберите фото блюда из галереи</string>
  <key>NSCameraUsageDescription</key>
  <string>Сделайте фото блюда</string>
  ```
- [ ] **Android** — добавить в `android/app/src/main/AndroidManifest.xml` внутри `<application>`:
  ```xml
  <activity
      android:name="com.yalantis.ucrop.UCropActivity"
      android:screenOrientation="portrait"
      android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
  ```
- [ ] Запустить `flutter build ios --no-codesign` (или на реальном устройстве) — убедиться что сборка проходит
- [ ] Запустить `flutter build apk --debug` — убедиться что UCropActivity присутствует

> ⚠️ Отсутствие `UCropActivity` = тихий краш на Android при открытии кроппера. Проверить в первую очередь.

---

## Блок 6 — Flutter: Слой данных

### TICKET-012 — Добавить метод `fetchAllergens` в `MenuRepository`

**Файл:** `lib/data/repositories/menu_repository.dart`  
**Зависимости:** TICKET-006  
**Тест:** TICKET-012-T

#### Технические шаги
- [ ] Добавить метод `fetchAllergens()` по аналогии с существующим `fetchTags()`:
  ```dart
  Future<List<ApiAllergen>> fetchAllergens() async { ... }
  ```
- [ ] Убедиться что `ApiAllergen` модель существует (из `api_dish.dart` или отдельный файл) — если нет, создать минимальную модель `{id, name}`
- [ ] Кешировать результат так же как теги (или не кешировать, список редко меняется)

#### Тест TICKET-012-T
- [ ] `test_fetchAllergens_returns_list` — мок Dio, ответ 200 с массивом → список `ApiAllergen`
- [ ] `test_fetchAllergens_empty_list` — ответ `[]` → пустой список, не краш

---

### TICKET-013 — Добавить CRUD + upload методы в `MenuRepository`

**Файл:** `lib/data/repositories/menu_repository.dart`  
**Зависимости:** TICKET-005, TICKET-011  
**Тест:** TICKET-013-T

#### Технические шаги
- [ ] `fetchAdminDishes()` — GET `/menu/admin/dishes/`, возвращает `List<ApiDish>` (включая `is_active=false`)
- [ ] `createDish(Map<String, dynamic> fields, {File? image})`:
  - Собрать `FormData.fromMap({...fields, 'image': MultipartFile.fromFile(...)})`
  - POST multipart на `/menu/admin/dishes/`
  - Вернуть `ApiDish.fromJson(response.data)`
- [ ] `updateDish(int id, Map<String, dynamic> fields, {File? image})`:
  - С image → PATCH multipart
  - Без image → PATCH `application/json`
- [ ] `deleteDish(int id)` — DELETE `/menu/admin/dishes/$id/`
- [ ] Проверить передачу списков (tags, allergens) в multipart:
  - Тест с `curl -F "tags=1" -F "tags=2"` — если DRF не парсит, переключиться на `tags_json="[1,2]"` + обработка в `StaffDishSerializer.validate()`
- [ ] Убедиться что `AuthInterceptor` в `DioClient` добавляет `Bearer` токен автоматически (уже реализовано)

#### Тест TICKET-013-T
**Файл:** `test/repositories/menu_repository_test.dart`
- [ ] `test_fetchAdminDishes_returns_all` — мок, ответ включает inactive → список
- [ ] `test_createDish_sends_multipart` — verifyThat Dio.post вызван с FormData
- [ ] `test_updateDish_with_image_sends_multipart` — PATCH с image → FormData
- [ ] `test_updateDish_without_image_sends_json` — PATCH без image → JSON body
- [ ] `test_deleteDish_calls_delete` — verifyThat Dio.delete вызван с правильным URL

---

## Блок 7 — Flutter: Admin UI

### TICKET-014 — Admin overlay (иконка карандаша) на `_ClassicDishCard`

**Файл:** `lib/screens/menu_screen.dart`  
**Зависимости:** TICKET-010  
**Тест:** TICKET-014-T

#### Технические шаги
- [ ] Добавить `required this.isAdmin` в конструктор `_ClassicDishCard`
- [ ] Внутри `Stack` изображения, после существующих градиентов, добавить:
  ```dart
  if (isAdmin)
    Positioned(
      top: 10, right: 10,
      child: _AdminEditButton(onTap: () => _openDishEdit(context, dish)),
    ),
  ```
- [ ] Создать `_AdminEditButton` — круглая кнопка 36×36:
  - фон: `PiligrimColors.earthDeep` с opacity 0.85
  - иконка: карандаш, `PiligrimColors.water`
  - `PiligrimTap` для haptic feedback
- [ ] В `_buildClassicItems` читать `isAdmin` один раз: `final isAdmin = context.read<AuthProvider>().isAdmin`
- [ ] Передавать `isAdmin` в каждый `_ClassicDishCard`
- [ ] Убедиться что без флага admin кнопка физически отсутствует в дереве (не просто invisible)

#### Тест TICKET-014-T
**Файл:** `test/widgets/classic_dish_card_test.dart`
- [ ] `test_admin_edit_button_visible_when_is_admin` — `isAdmin=true` → `_AdminEditButton` в дереве
- [ ] `test_admin_edit_button_absent_for_regular_user` — `isAdmin=false` → кнопки нет

---

### TICKET-015 — FAB «Добавить блюдо» на `MenuScreen`

**Файл:** `lib/screens/menu_screen.dart`  
**Зависимости:** TICKET-010  
**Тест:** TICKET-015-T

#### Технические шаги
- [ ] В `_MenuScreenState.build()` добавить `floatingActionButton`:
  ```dart
  floatingActionButton: (isClassicMode && context.watch<AuthProvider>().isAdmin)
    ? FloatingActionButton(
        backgroundColor: PiligrimColors.earthWarm,
        child: Icon(Icons.add, color: PiligrimColors.water),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DishEditScreen(dish: null, categories: ...)),
        ),
      )
    : null,
  ```
- [ ] FAB появляется только в режиме `classic` (не в video feed режиме)
- [ ] Убедиться что FAB не перекрывает список (scaffold `extendBody=false` в `RootShell`)
- [ ] Проверить на физическом устройстве — FAB над bottom nav bar

#### Тест TICKET-015-T
- [ ] `test_fab_visible_for_admin_in_classic_mode` — admin + classic mode → FAB отображается
- [ ] `test_fab_hidden_for_regular_user` — обычный пользователь → FAB отсутствует
- [ ] `test_fab_hidden_in_video_mode` — admin + video mode → FAB отсутствует

---

## Блок 8 — Flutter: DishEditScreen

### TICKET-016 — Скелет `DishEditScreen` (форма без отправки)

**Файл:** `lib/screens/dish_edit_screen.dart` (новый файл)  
**Зависимости:** TICKET-009, TICKET-012  
**Тест:** TICKET-016-T

#### Технические шаги
- [ ] Создать `DishEditScreen(StatefulWidget)`:
  ```dart
  final ApiDish? dish;         // null = режим создания
  final List<ApiCategory> categories;
  ```
- [ ] Инициализировать `TextEditingController` для: name, description, price, weight, story
- [ ] В `initState`: если `dish != null` — заполнить контроллеры существующими данными
- [ ] Построить форму с `Form(key: _formKey)`:
  - Текстовые поля с валидаторами (name required, price — валидное число)
  - `DropdownButton<int>` для категории
  - Чекбоксы или `MultiSelectChip` для тегов и аллергенов
  - `Switch` для `is_active`
- [ ] AppBar: кнопка «Назад» + в режиме редактирования — иконка корзины (delete)
- [ ] Дизайн: фон `PiligrimColors.earth`, акцент полей `PiligrimColors.water`, стиль по аналогии с `_SearchBar` из `menu_screen.dart`
- [ ] **Без отправки на сервер** — заглушка `_save()` только логирует данные

#### Тест TICKET-016-T
- [ ] `test_screen_renders_in_create_mode` — `dish=null` → поля пустые
- [ ] `test_screen_renders_in_edit_mode` — `dish=someDish` → поля заполнены данными блюда
- [ ] `test_validation_name_required` — submit без name → ошибка валидации
- [ ] `test_validation_price_numeric` — price="abc" → ошибка

---

### TICKET-017 — Image picker + cropper в `DishEditScreen`

**Файл:** `lib/screens/dish_edit_screen.dart`  
**Зависимости:** TICKET-011, TICKET-016  
**Тест:** ручной (платформо-зависимый)

#### Технические шаги
- [ ] Добавить `File? _localImageFile` в state
- [ ] Реализовать `_pickAndCropImage()`:
  ```dart
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
    uiSettings: [
      AndroidUiSettings(toolbarTitle: 'Кадрировать 16:9', lockAspectRatio: true),
      IOSUiSettings(title: 'Кадрировать 16:9', aspectRatioLockEnabled: true),
    ],
  );
  if (cropped != null) setState(() => _localImageFile = File(cropped.path));
  ```
- [ ] Кроппер **всегда 16:9** с `lockAspectRatio: true` — пользователь не может изменить соотношение
- [ ] Добавить кнопку «Выбрать фото» под зоной предпросмотра
- [ ] При отсутствии `_localImageFile` в edit mode — показывать `CachedNetworkImage(dish!.imageUrl)`
- [ ] При отсутствии обоих — показывать placeholder (иконка камеры на `PiligrimColors.earthDeep` фоне)
- [ ] Протестировать на iOS: галерея открывается, кроппер с 16:9 рамкой
- [ ] Протестировать на Android: галерея открывается, UCropActivity запускается, 16:9 locked

---

### TICKET-018 — Live Preview карточки в `DishEditScreen`

**Файл:** `lib/screens/dish_edit_screen.dart`  
**Зависимости:** TICKET-017

#### Технические шаги
- [ ] В верхней части `DishEditScreen` разместить preview-виджет (16:9 AspectRatio)
- [ ] Preview зеркалит визуал `_ClassicDishCard`:
  - Изображение: `Image.file(_localImageFile)` или `CachedNetworkImage(dish.imageUrl)` или placeholder
  - Нижний градиент с названием блюда (читать из `_nameController.text`)
  - Ценник (читать из `_priceController.text`)
- [ ] Preview реактивен: обновляется при каждом `setState` (смена фото, изменение названия)
- [ ] **Не использовать** `_ClassicDishCard` напрямую (он принимает `ApiDish` — его ещё нет). Написать отдельный простой preview widget.
- [ ] Убедиться что preview не ломается при пустых полях (name="", price="")

---

### TICKET-019 — Сохранение и удаление блюда

**Файл:** `lib/screens/dish_edit_screen.dart`  
**Зависимости:** TICKET-013, TICKET-016  
**Тест:** TICKET-019-T

#### Технические шаги
- [ ] Реализовать `_save()`:
  ```dart
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isSaving = true);
  try {
    final fields = {
      'name': _nameCtrl.text.trim(),
      'price': int.parse(_priceCtrl.text),
      'category': _selectedCategoryId,
      'is_active': _isActive,
      // ...остальные поля
    };
    widget.dish == null
      ? await _repo.createDish(fields, image: _localImageFile)
      : await _repo.updateDish(widget.dish!.id, fields, image: _localImageFile);
    if (mounted) context.read<MenuProvider>().load(); // Refresh menu
    if (mounted) Navigator.of(context).pop();
  } catch (e) {
    // Показать SnackBar с сообщением об ошибке
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
  ```
- [ ] Кнопка «Опубликовать» — `PiligrimColors.steppe`, disabled при `_isSaving=true`
- [ ] При `_isSaving=true` показывать `PiligrimLoader` вместо кнопки
- [ ] Реализовать `_deleteDish()`:
  - `showDialog` с подтверждением (две кнопки: «Отмена» / «Удалить»)
  - На confirm: `await _repo.deleteDish(widget.dish!.id)`
  - Refresh menu + `Navigator.pop()`
- [ ] Обработать `DioException` отдельно (сетевая ошибка vs 400 ValidationError)
- [ ] Для 400: показать конкретные ошибки из `e.response?.data` в SnackBar

#### Тест TICKET-019-T
- [ ] `test_save_calls_createDish_in_create_mode` — mock repo, submit → `createDish` вызван
- [ ] `test_save_calls_updateDish_in_edit_mode` — mock repo, submit → `updateDish` вызван с id
- [ ] `test_save_disabled_while_saving` — во время `_isSaving` кнопка неактивна
- [ ] `test_delete_shows_confirmation_dialog` — тап корзины → dialog
- [ ] `test_delete_confirmed_calls_deleteDish` — подтверждение → `deleteDish` вызван

---

## Блок 9 — Сквозное тестирование

### TICKET-020 — Integration test: полный flow создания блюда

**Файл:** `test/integration/admin_create_dish_test.dart`  
**Зависимости:** все предыдущие тикеты

#### Технические шаги
- [ ] Запустить локальный бэкенд (`docker compose up`)
- [ ] Создать test-пользователя с `role=admin`
- [ ] Аутентифицировать через `POST /api/v1/users/auth/verify-sms/`
- [ ] Проверить что `GET /api/v1/users/profile/` возвращает `is_staff=true`
- [ ] Во Flutter: войти как admin → `AuthProvider.isAdmin == true`
- [ ] Открыть `MenuScreen` → FAB присутствует, карандаши на карточках присутствуют
- [ ] Открыть `DishEditScreen`, заполнить форму, выбрать фото
- [ ] Нажать «Опубликовать» → API возвращает 201
- [ ] Проверить что новое блюдо появилось в `MenuScreen`
- [ ] Проверить что неаутентифицированный `GET /api/v1/menu/admin/dishes/` возвращает 403

---

### TICKET-021 — Smoke test: обычный пользователь не видит admin UI

**Зависимости:** TICKET-014, TICKET-015

#### Технические шаги
- [ ] Войти как обычный пользователь
- [ ] Открыть `MenuScreen`:
  - [ ] FAB отсутствует в дереве виджетов
  - [ ] Карандаши на карточках отсутствуют
- [ ] Попытаться вручную отправить запрос на `POST /api/v1/menu/admin/dishes/` с обычным токеном → 403
- [ ] Убедиться что в production-build нет утечки admin-данных в UI

---

## Зависимости между тикетами (граф)

```
TICKET-001 ──────────────────────────────────────► TICKET-009
TICKET-002 ──► TICKET-003 ──► TICKET-004 ──► TICKET-005 ──► TICKET-006
                                                     │
                                                     └──────────────────► TICKET-013
TICKET-011 ──────────────────────────────────────────────────────────► TICKET-013
TICKET-009 ──► TICKET-010 ──► TICKET-014
                         └──► TICKET-015
TICKET-012 ──► TICKET-016 ──► TICKET-017 ──► TICKET-018 ──► TICKET-019
TICKET-013 ──────────────────────────────────────────────────────────► TICKET-019
```

---

## Оценка сложности и времени

| Блок | Тикеты | Время |
|---|---|---|
| Backend: ролевая модель | 001, 002 | 45 мин |
| Backend: write API | 003, 004, 005, 006 | 2 ч |
| Backend: документация | 007, 008 | 45 мин |
| Flutter: ролевая модель | 009, 010 | 35 мин |
| Flutter: пакеты + нативная конфиг | 011 | 25 мин |
| Flutter: слой данных | 012, 013 | 1.5 ч |
| Flutter: Admin UI (overlay + FAB) | 014, 015 | 1.5 ч |
| Flutter: DishEditScreen | 016, 017, 018, 019 | 4 ч |
| Тесты (backend) | 001-T — 006-T | 2 ч |
| Тесты (flutter) | 009-T — 019-T | 1.5 ч |
| Сквозное тестирование | 020, 021 | 1 ч |
| **Итого** | **21 тикет** | **~15.5 ч (~2 рабочих дня)** |

---

## Ключевые риски

| Риск | Вероятность | Митигация |
|---|---|---|
| DRF не парсит repeated form keys (`tags=1&tags=2`) в multipart | Средняя | Тест curl перед Flutter. Fallback: `tags_json="[1,2]"` + `validate()` |
| Отсутствие `UCropActivity` в AndroidManifest → тихий краш | Высокая если пропустить | TICKET-011 проверяется первым делом |
| `price` как int в `ApiDish` vs `"4500.00"` от бэкенда | Средняя | Проверить `json_utils.parseInt` перед TICKET-013 |
| Refresh `MenuProvider` после save конфликтует с анимацией pop | Низкая | `addPostFrameCallback` если воспроизводится |
| `_ClassicDishCard` private в 1600-строчном файле | Нет | Изменения внутри того же файла, не выносить |

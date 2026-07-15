# 📱 Panno API Guide for Flutter Developers

В этом документе собрана вся необходимая информация для интеграции мобильного приложения (Flutter) с бэкендом (Django/DRF).

## 🚀 Базовые правила

- **Base URL (Local):** `http://localhost:8000` (для эмулятора Android: `http://10.0.2.2:8000`)
- **API Version:** Все эндпоинты используют префикс `/api/v1/`. Пример: `http://localhost:8000/api/v1/users/auth/request-sms/`
- **Формат данных:** Все запросы и ответы используют `application/json`.
- **Авторизация:** Большинство эндпоинтов закрыты. Используется JWT-авторизация. Токен передается в заголовке:
  ```http
  Authorization: Bearer <твой_access_token>
  ```
- **Пагинация:** Все списки (меню, история броней) возвращаются в формате:
  ```json
  {
    "count": 12,
    "next": "http://api.../?page=2",
    "previous": null,
    "results": [...]
  }
  ```
- **Кэширование на сервере:** Публичные эндпоинты кэшируются в Redis. Flutter может смело делать повторные запросы — лишней нагрузки на БД не будет. При изменении данных через админку кэш сбрасывается автоматически. TTL зависит от типа данных:
  - `GET /api/v1/core/info/` и `/api/v1/core/interior/` — **1 час** (статичные данные)
  - `GET /api/v1/menu/categories/` — **1 час**
  - `GET /api/v1/menu/dishes/` — **5 минут** (параметры фильтрации кэшируются раздельно)
  - `GET /api/v1/menu/feed/` — **не кэшируется** (курсор кодирует позицию конкретного запроса, кэш сломал бы навигацию по страницам)
  - `GET /api/v1/events/upcoming/` и `/archived/` — **60 секунд** (зависят от текущего времени)
  - `GET /api/v1/events/news/` — **5 минут**

---

## 🖼️ Медиафайлы (фото и видео)

- **Все поля `image`** во всех эндпоинтах возвращают **абсолютный URL** (`https://...`). Никогда не относительный путь. Используй значение напрямую в `CachedNetworkImage`.
- **Все изображения** автоматически обрезаются до **16:9** при загрузке через Django Admin (кроме фотоотчётов мероприятий и фото интерьера, которые отображаются fullscreen).
- **Формат:** JPEG, max 1200px по ширине, 85% качество.
- **`video_url`** — аналогично, всегда абсолютный URL. Показывай плеер только при `video_status == "ready"`.
- **`MEDIA_ORIGIN`** для Flutter (сборка через `--dart-define`): `https://piligrim.kz` (продакшн), `http://10.0.2.2:8000` (Android эмулятор), `http://localhost:8000` (iOS симулятор).

---

## 🔐 1. Авторизация и Профиль

Авторизация работает без паролей, только через SMS (OTP код).

### 1.1 Запрос SMS-кода
`POST /api/v1/users/auth/request-sms/` (Без авторизации)
- **Body:** `{"phone": "+77001234567"}`
- **Response (200):** SMS отправлена. Код живет 3 минуты. (В режиме разработки код пишется в консоль бэкенда).
- **Response (503):** Сервис временно недоступен (инфраструктурная ошибка). Показать пользователю: «Попробуйте позже».

### 1.2 Подтверждение SMS и получение токена
`POST /api/v1/users/auth/verify-sms/` (Без авторизации)
- **Body:** `{"phone": "+77001234567", "otp": "4823"}`
- **Response (200):**
  ```json
  {
    "message": "Успешная авторизация",
    "is_new_user": true,
    "user_id": 42,
    "access": "eyJhbG...",
    "refresh": "eyJhbG..."
  }
  ```
  - `is_new_user: true` — пользователь только что зарегистрировался. Используй этот флаг, чтобы показать экран заполнения имени/фамилии (onboarding). При `false` — сразу веди на главный экран.
  - `user_id` — ID пользователя (пригодится для аналитики).
  - Сохрани `access` и `refresh` в `flutter_secure_storage`. Если юзера не было, он создаётся автоматически.

### 1.3 Обновление access-токена
`POST /api/v1/users/auth/token/refresh/` (Без авторизации)
- **Когда вызывать:** При получении `401 Unauthorized` на любом защищённом запросе.
- **Body:** `{"refresh": "<твой_refresh_token>"}`
- **Response (200):**
  ```json
  { "access": "eyJhbG..." }
  ```
  Сохрани новый `access` в `flutter_secure_storage` и повтори исходный запрос.
- **Response (401):** refresh-токен тоже истёк (после 7 дней неактивности) — перенаправь пользователя на экран входа через SMS.

**Рекомендуемая схема в Dio (interceptor):**
```dart
// В onError interceptor: если 401 — пробуем обновить access
if (error.response?.statusCode == 401) {
  final refreshToken = await storage.read(key: 'refresh');
  final resp = await dio.post('/api/v1/users/auth/token/refresh/',
      data: {'refresh': refreshToken});
  if (resp.statusCode == 200) {
    final newAccess = resp.data['access'];
    await storage.write(key: 'access', value: newAccess);
    // Повторяем исходный запрос с новым токеном
    error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
    return dio.fetch(error.requestOptions);
  }
  // Если 401 на refresh — разлогиниваем
  await _logout();
}
```

### 1.4 Выход из системы (Logout)
`POST /api/v1/users/auth/logout/` (Требует авторизации)
- **Body:** `{"refresh": "<твой_refresh_token>"}`
- **Response (204):** тело пустое — logout выполнен. Удали оба токена из `flutter_secure_storage`.
- **Response (400):** токен уже отозван или невалиден.
- **Response (401):** не передан access-токен в заголовке.

> **Важно:** после logout refresh-токен помещается в blacklist на сервере — его больше нельзя использовать. access-токен продолжает жить до конца своего TTL (30 мин в проде), но после удаления из хранилища клиент всё равно потеряет доступ.

**Схема реализации logout в Flutter:**
```dart
Future<void> logout() async {
  final refreshToken = await storage.read(key: 'refresh');
  final accessToken = await storage.read(key: 'access');

  try {
    await dio.post(
      '/api/v1/users/auth/logout/',
      data: {'refresh': refreshToken},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  } catch (_) {
    // Даже если запрос упал — всё равно чистим локальное хранилище
  }

  await storage.delete(key: 'access');
  await storage.delete(key: 'refresh');
  // Перенаправить на экран входа
}
```

### 1.5 Удаление аккаунта
`DELETE /api/v1/users/account/` (Требует авторизации)
- **Response (204):** тело пустое — аккаунт и связанные данные удалены на сервере. Очисти локальные JWT и покажи неавторизованный экран.
- **Response (401):** не передан или недействителен access-токен.
- **Response (403):** удаление через приложение запрещено (например, staff-аккаунт).

> **Важно:** удаление безвозвратное (профиль, брони, записи на события, FCM-устройства). Отдельный logout после успешного DELETE не нужен — только очистка локального хранилища.

### 1.6 Профиль пользователя
- **Получить профиль:** `GET /api/v1/users/profile/`
  ```json
  {
    "id": 1,
    "phone": "+77001234567",
    "first_name": "Алихан",
    "last_name": "Сейткали",
    "city": "Алматы",
    "notifications_enabled": true,
    "notify_events": true,
    "notify_promotions": true,
    "notify_closed_events": true
  }
  ```
- **Обновить профиль:** `PATCH /api/v1/users/profile/`
  - **Body (любые поля):**
    ```json
    {
      "first_name": "Алихан",
      "last_name": "Сейткали",
      "city": "Алматы",
      "notifications_enabled": false,
      "notify_events": false,
      "notify_promotions": true,
      "notify_closed_events": false
    }
    ```
  - *Примечание:* Номер телефона и ID изменить нельзя.
  - `city` — передавай из геолокации пользователя, если он дал разрешение. Используется для адресных рассылок по городу.

**Категории push-уведомлений:**

| Поле | Описание |
|---|---|
| `notifications_enabled` | Глобальный выключатель маркетинговых пушей. `false` — блокирует все категории (не влияет на сервисные). |
| `notify_events` | Уведомления о мероприятиях и афише |
| `notify_promotions` | Акции и спецпредложения |
| `notify_closed_events` | Закрытые/VIP события |
| Сервисные (бронь, напоминания) | Всегда приходят, отключить нельзя |

---

## 🍔 2. Меню ресторана

### 2.1 Категории
`GET /api/v1/menu/categories/`
- Возвращает **плоский массив** категорий (отсортированных по `order`). Использовать для верхнего таб-бара.
- **Без пагинации** — ответ: `[{"id": 1, "name": "Горячие", "order": 1}, ...]`

### 2.2 Теги
`GET /api/v1/menu/tags/`
- Возвращает **плоский массив** всех тегов, отсортированных по имени.
- **Без пагинации** — ответ: `[{"id": 1, "name": "Вегетарианское"}, {"id": 2, "name": "Острое"}, ...]`
- Загружать при инициализации меню (параллельно с категориями) для наполнения фильтр-чипов.

### 2.2.1 Аллергены
`GET /api/v1/menu/allergens/` (Без авторизации)
- Возвращает **плоский массив** всех аллергенов, отсортированных по имени.
- **Без пагинации** — ответ: `[{"id": 1, "name": "Глютен"}, {"id": 2, "name": "Лактоза"}, {"id": 3, "name": "Орехи"}, ...]`
- Загружать при инициализации admin-панели редактирования блюда (для чекбоксов выбора аллергенов).

### 2.3 Список блюд (классическое меню)
`GET /api/v1/menu/dishes/`
- По умолчанию отдает **5 блюд** на страницу. Пагинация — страничная (`?page=2`).
- **Query параметры:**
  - `?category_id=1` — фильтр по категории
  - `?tag_ids=2,5,8` — фильтр по нескольким тегам. Через запятую — блюдо должно иметь хотя бы один из указанных тегов
  - `?search=бургер` — поиск по названию и описанию
  - `?page=2` — следующая страница
- **Ответ:** Содержит полные данные о блюде. Поля:
  - `image` — **абсолютный URL** фото блюда (JPEG 16:9, max 1200px). Всегда `https://...`, никогда не относительный путь.
  - `video_url` — **абсолютный URL** обработанного видео (H.264 720×1280); `null` если видео ещё не прошло транскодирование. **Используй это поле** для воспроизведения. Поле `video` (сырой оригинал) больше не возвращается.
  - `video_status` — статус обработки видео (см. таблицу ниже). Воспроизводить видео только при `video_status == "ready"`.
  - `weight` — вес блюда в граммах (`null` если не задан)
  - `story` — история блюда (для экрана расширенного описания; пустая строка если не задана)

### 2.3 Видеолента блюд
`GET /api/v1/menu/feed/` (Без авторизации)
- Возвращает **только активные блюда с готовым видео** (`video_status=ready`). Используй этот эндпоинт для бесконечной видеоленты (аналог TikTok/Reels).
- **Пагинация: курсорная** — не страничная. Для перехода к следующей порции передай значение поля `next` как параметр `cursor`.

```dart
// Первая страница
final r1 = await dio.get('/api/v1/menu/feed/');
final nextUrl = r1.data['next']; // null, если это последняя страница

// Следующая страница
if (nextUrl != null) {
  final cursor = Uri.parse(nextUrl).queryParameters['cursor'];
  final r2 = await dio.get('/api/v1/menu/feed/', queryParameters: {'cursor': cursor});
}
```

- **Ответ:**
  ```json
  {
    "next": "http://localhost:8000/api/v1/menu/feed/?cursor=abc123",
    "previous": null,
    "results": [...]
  }
  ```
  > Поле `count` отсутствует — это особенность курсорной пагинации.

**Статусы видео (`video_status`):**

| Значение | Описание | Что показывать |
|---|---|---|
| `pending` | Видео загружено, ожидает очереди | Заглушку / фото блюда |
| `processing` | FFmpeg транскодирует видео | Индикатор загрузки |
| `ready` | Видео готово — `video_url` заполнен | Видеоплеер с `video_url` |
| `failed` | Ошибка транскодирования | Фото блюда, без видео |

> **Совет:** в ленте `/feed/` все блюда всегда имеют `video_status=ready` и непустой `video_url`, поэтому дополнительная проверка статуса не нужна. В классическом меню `/dishes/` проверяй `video_url != null` перед воспроизведением.

---

## 📅 3. Бронирование столов (Bookings)

### 3.1 Создать бронь
`POST /api/v1/bookings/`
- **Body:**
  ```json
  {
    "guest_name": "Алихан Сейткали",
    "phone": "+77001234567",
    "date": "2026-06-15",
    "time": "19:30:00",
    "guests_count": 4,
    "comment": "Нужен детский стул",
    "zone": "terrace"
  }
  ```
  - `phone` — опционально. Рекомендуется передавать, чтобы менеджер мог перезвонить гостю. Если пользователь авторизован, передавай `user.phone` из профиля.
  - `zone` — опционально. Доступные значения: `"main"` (Главный зал), `"terrace"` (Терраса), `"private"` (Приват). Если не нужен — не передавай поле.
- **Response (201):** Создано (статус по умолчанию `pending`). Ответ содержит поле `phone`.
- **Push после создания:** Пользователь автоматически получает push *«Заявка принята, мы свяжемся с вами в ближайшее время.»*
- **Push при подтверждении:** *«Ваш столик забронирован на ДД.ММ.ГГГГ в ЧЧ:ММ. Ждём вас!»* — дата и время подставляются из брони.
- **Push-напоминания:** За 1–2 часа до визита пользователь получает push-напоминание о брони (сервисное, отключить нельзя).

Оплата через приложение не принимается ни в каком виде — форма бронирования показывает статичный дисклеймер об этом.

### 3.1.2 Экран успеха после отправки заявки

После успешного `POST /api/v1/bookings/` форма очищается и происходит `Navigator.push` на `BookingSuccessScreen`:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => BookingSuccessScreen(
      date: dateText,         // «ДД.ММ.ГГГГ»
      time: timeText,         // «ЧЧ:ММ»
      heroesCount: count,
      zone: zoneText,         // читаемое название или null
    ),
  ),
);
```

С экрана успеха пользователь может перейти в историю броней («МОИ БРОНИРОВАНИЯ») или на главную («НА ГЛАВНУЮ»).

### 3.2 Моя история броней
`GET /api/v1/bookings/`
- Возвращает все брони текущего пользователя (с пагинацией), отсортированные по дате визита по убыванию (самые поздние/будущие первыми).

---

## 🎉 4. Мероприятия (Afisha) и Новости

### 4.1 Списки (Афиша и Новости)
- **Предстоящие (Афиша):** `GET /api/v1/events/upcoming/` (Без авторизации)
- **Прошедшие (Архив):** `GET /api/v1/events/archived/` (Без авторизации)
- **Новости:** `GET /api/v1/events/news/` (Без авторизации)

**Поля карточки мероприятия:**

| Поле | Тип | Описание |
|---|---|---|
| `format` | string | `"open"` — открытое мероприятие, `"closed"` — закрытое/VIP |
| `price` | decimal / null | Цена входа. `null` — вход свободный |

*Пример:* `{"format": "closed", "price": "3500.00"}` — закрытое событие, билет 3500 ₸.

### 4.2 Запись на мероприятие
`POST /api/v1/events/reservations/create/` (Требует авторизации)
- **Body:** `{"event": 3, "guests_count": 2}`
- **Ограничение:** Нельзя записаться на одно мероприятие дважды (вернет 400 ошибку).

### 4.3 Мои записи на мероприятия
`GET /api/v1/events/reservations/my/` (Требует авторизации)
- Возвращает список записей, внутри которых вложен объект `event_details` с полной информацией о самом событии.

---

## ℹ️ 5. Инфраструктура

### 5.1 Инфо о ресторане (Контакты, карты, 3D-тур)
`GET /api/v1/core/info/` (Без авторизации)
- Возвращает всю статическую информацию о ресторане.
  ```json
  {
    "address": "г. Алматы, ул. Примерная, 1",
    "working_hours": "Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00",
    "working_hours_note": "Закрыто 1 января",
    "is_open_now": true,
    "phone": "+77273334455",
    "whatsapp": "+77001234567",
    "telegram": "@panno_almaty",
    "instagram": "@panno_almaty",
    "concept_description": "Modern Nomad — кухня кочевников...",
    "hero_slides": [
      {
        "id": 1,
        "image": "https://cdn.example.com/media/core/hero/slide1.jpg",
        "order": 0
      },
      {
        "id": 2,
        "image": "https://cdn.example.com/media/core/hero/slide2.jpg",
        "order": 1
      }
    ],
    "tour_link": "https://...",
    "twogis_link": "https://2gis.kz/...",
    "feedback_url": "https://wa.me/77001234567",
    "visit_rules": [
      {"title": "Дресс-код", "body": "Деловой casual..."},
      {"title": "Дети", "body": "Приветствуются до 21:00..."}
    ],
    "privacy_policy": "Текст политики обработки ПД...",
    "terms_of_service": "Текст пользовательского соглашения..."
  }
  ```

| Поле | Описание |
|---|---|
| `working_hours` | Основное расписание в текстовом виде (напр. `Пн–Пт: 12:00–23:00, Сб–Вс: 12:00–00:00`) |
| `working_hours_note` | Временное изменение режима — пустая строка если нет уведомления. Показывай поверх `working_hours` если не пустое (напр. «Закрыто 1 января»). |
| `is_open_now` | `true` / `false` — вычисляется по `working_hours` в реальном времени (часовой пояс Asia/Almaty) |
| `concept_description` | Краткое описание концепции ресторана (для главного экрана). Пустая строка если не заполнено. |
| `hero_slides` | Массив изображений-слайдов для главного экрана (может быть пустым списком `[]`). Каждый объект содержит `id`, `image` (URL) и `order`. |
| `phone` | Телефон ресторана |
| `whatsapp` | WhatsApp-контакт (ссылка или номер) |
| `telegram` | Telegram (username или ссылка) |
| `instagram` | Instagram handle |
| `visit_rules` | Правила посещения — массив объектов `{"title": "...", "body": "..."}`, отсортированных по полю `order`. Пустой список `[]` если не заполнено. |
| `privacy_policy` | URL политики обработки персональных данных (для экрана согласия) |
| `terms_of_service` | URL пользовательского соглашения |
| `tour_link` | URL для WebView 3D-тура (`null` если не задано) |
| `twogis_link` | URL маршрута в 2ГИС (`null` если не задано) — единственный поддерживаемый картографический сервис |
| `feedback_url` | URL для обратной связи (WhatsApp, форма, mailto: и т.п.). `null` если не задано. |

### 5.1.1 Галерея интерьера (вкладка «3D-тур / Интерьер»)
`GET /api/v1/core/interior/` (Без авторизации)
- Возвращает фотографии интерьера, отсортированные по зонам.
  ```json
  [
    {
      "id": 1,
      "zone": "main_hall",
      "zone_display": "Главный зал",
      "image": "https://cdn.example.com/media/interior/hall1.jpg",
      "caption": "Вид на основной зал с барной стойкой",
      "order": 1
    },
    {
      "id": 2,
      "zone": "terrace",
      "zone_display": "Терраса",
      "image": "https://cdn.example.com/media/interior/terrace1.jpg",
      "caption": "",
      "order": 1
    }
  ]
  ```

**Зоны:** `main_hall` (Главный зал), `bar` (Бар), `private` (Приватная комната), `terrace` (Терраса), `other` (Другое).
Без пагинации — фотографий обычно немного, загружай весь список сразу.

#### Обработка `tour_link` на стороне Flutter

`tour_link` приходит как `String | null` из `GET /api/v1/core/info/`.
Доступен в приложении как `CoreInfoProvider.coreInfo?.tourLink`.

| Значение | Поведение |
|----------|-----------|
| `null` или пустая строка | Кнопка «3D-тур» не отображается на экране «Интерьер» |
| Непустая строка | Показывается кнопка `_TourButton`; нажатие вызывает `launchUrl(uri, mode: LaunchMode.externalApplication)` |

`webview_flutter` не используется — тур открывается в системном браузере (полностью поддерживает WebGL/сферические панорамы). Если открытие невозможно (браузер не установлен) — показывается SnackBar с ошибкой.

#### Поля `zone_display` и `caption` из `/core/interior/`

| Поле | Использование |
|------|---------------|
| `zone` | Ключ фильтрации (slug: `main_hall`, `terrace` и т.д.) |
| `zone_display` | Отображаемое название зоны в фильтре и в подписях фото |
| `caption` | Подпись фотографии в fullscreen-просмотрщике (может быть пустой строкой) |

На экране «Интерьер» реализован горизонтальный фильтр по уникальным зонам из полученных данных. Первый фильтр — «Все» (показывает весь список). По тапу на фото открывается `InteriorPhotoViewer` с `InteractiveViewer` (pinch-to-zoom 1.0–4.0) и листанием через `PageView`.

### 5.2 Версия приложения (Force Update)
`GET /api/v1/core/app-version/?platform=ios` или `?platform=android` (Без авторизации)
- Вызывать при запуске приложения, до отображения главного экрана.
- **Response (200):**
  ```json
  {
    "platform": "android",
    "min_version": "1.0.0",
    "latest_version": "1.3.0",
    "store_url": "https://play.google.com/store/apps/details?id=kz.panno",
    "updated_at": "2026-05-12T10:00:00+06:00"
  }
  ```
- **Логика на клиенте:**
  - Если `current_version < min_version` → показывай диалог принудительного обновления (нельзя закрыть).
  - Если `min_version ≤ current_version < latest_version` → показывай баннер "Доступно обновление" (можно закрыть).
  - Если `current_version == latest_version` → всё актуально.
- **Response (404):** если `platform` не передан или значение неизвестно.

### 5.3 Push-уведомления (Регистрация устройства)
`POST /api/v1/notifications/device/register/`
- **Когда вызывать:** При успешном логине и при обновлении токена `FirebaseMessaging.instance.getToken()`.
- **Body:** `{"fcm_token": "token_string_here..."}`

**Важно о маркетинговых пушах (category != null):**
- Пользователь получит не более **3 маркетинговых пушей в неделю** (лимит устанавливается на сервере).
- Маркетинговые пуши отправляются только **с 09:00 до 21:00** по местному времени сервера (Asia/Almaty). Если рассылка запущена ночью, пуш придёт утром.
- Сервисные пуши (подтверждение/отмена брони, напоминания) приходят всегда, без ограничений.

---

## 🛠️ 6. Admin Panel (Staff Only)

Функционал доступен только пользователям с `is_staff=true`. Флаг возвращается в `GET /api/v1/users/profile/`.

### 6.1 Определение роли на клиенте

```dart
// После успешного логина загрузи профиль
final profile = await userRepository.getProfile(); // GET /api/v1/users/profile/
if (profile.isStaff) {
  // Показать кнопку/вкладку «Управление меню» в profile screen
}
```

`is_staff` — булево поле в ответе профиля. Кнопка входа в admin UI показывается только при `true`. Обычный авторизованный пользователь (`is_staff=false`) не видит admin-элементов.

---

### 6.2 Список всех блюд (включая неактивные)
`GET /api/v1/menu/admin/dishes/` (Staff only)

Возвращает все блюда без пагинации, включая `is_active=false`.

```dart
final resp = await dio.get('/api/v1/menu/admin/dishes/');
// resp.data — List<dynamic>, каждый элемент содержит image_url, is_active и т.д.
```

---

### 6.3 Создать блюдо
`POST /api/v1/menu/admin/dishes/` (Staff only)  
**Content-Type: `multipart/form-data`** — обязателен, так как передаётся `image`.

```dart
Future<void> createDish({
  required String name,
  required String price,
  required int categoryId,
  required File imageFile,
  String? description,
  String? story,
  int? weight,
  bool isActive = true,
  List<int> tagIds = const [],
  List<int> allergenIds = const [],
}) async {
  final formData = FormData.fromMap({
    'name': name,
    'price': price,
    'category': categoryId,
    'description': description ?? '',
    'story': story ?? '',
    if (weight != null) 'weight': weight,
    'is_active': isActive,
    'image': await MultipartFile.fromFile(
      imageFile.path,
      filename: path.basename(imageFile.path),
    ),
    // Списки передаются как повторяющиеся поля
    for (final id in tagIds) 'tags': id,
    for (final id in allergenIds) 'allergens': id,
  });

  await dio.post('/api/v1/menu/admin/dishes/', data: formData);
}
```

> **Автообрезка изображений:** загружай фото в любом формате (PNG, HEIC, JPEG, любое соотношение сторон) — бэкенд автоматически обрежет до 16:9, сконвертирует в JPEG (max 1200px, quality 85) и сохранит с UUID-именем. Оригинальное имя файла не сохраняется. В ответе `image_url` вернёт абсолютный URL обрезанного файла.

---

### 6.4 Полное обновление блюда (с заменой фото)
`PUT /api/v1/menu/admin/dishes/{id}/` (Staff only)  
**Content-Type: `multipart/form-data`**

Аналогично созданию — передавать все поля + `image` если нужно заменить фото.

```dart
final formData = FormData.fromMap({
  'name': updatedName,
  'price': updatedPrice,
  'category': categoryId,
  'is_active': isActive,
  'image': await MultipartFile.fromFile(newImageFile.path),
  // ... остальные поля
});

await dio.put('/api/v1/menu/admin/dishes/$dishId/', data: formData);
```

---

### 6.5 Частичное обновление блюда (без замены фото)
`PATCH /api/v1/menu/admin/dishes/{id}/` (Staff only)

**Без `image`** → отправлять `application/json` (не multipart):

```dart
// Обновить только цену и статус активности
await dio.patch(
  '/api/v1/menu/admin/dishes/$dishId/',
  data: {'price': '5500.00', 'is_active': false},
  options: Options(contentType: 'application/json'),
);
```

**С новым `image`** → использовать `multipart/form-data` (как в PUT).

---

### 6.6 Удалить блюдо
`DELETE /api/v1/menu/admin/dishes/{id}/` (Staff only)

```dart
await dio.delete('/api/v1/menu/admin/dishes/$dishId/');
// Response 204 — тело пустое. Файлы (image, video) удаляются автоматически на сервере.
```

---

### 6.7 Загрузка видео к блюду

`PATCH /api/v1/menu/admin/dishes/{id}/` (Staff only)  
**Content-Type: `multipart/form-data`** — обязателен при передаче видеофайла.

Поддерживаемые форматы: MP4, MOV (QuickTime), M4V. Любой другой тип → `400`.

```dart
Future<void> uploadDishVideo({
  required int dishId,
  required File videoFile,
}) async {
  final formData = FormData.fromMap({
    'video': await MultipartFile.fromFile(
      videoFile.path,
      filename: path.basename(videoFile.path),
      contentType: DioMediaType('video', 'mp4'),
    ),
  });

  await dio.patch(
    '/api/v1/menu/admin/dishes/$dishId/',
    data: formData,
    // Не передавать ContentType.json — форма с файлом!
  );
  // Ответ 200: video_status == "pending"
}
```

После `PATCH` бэкенд возвращает `video_status: "pending"`. Транскодирование происходит асинхронно в Celery. Flutter должен опрашивать детальный эндпоинт до получения `ready` или `failed`:

```dart
Future<String> waitForVideoReady(int dishId) async {
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    final resp = await dio.get('/api/v1/menu/admin/dishes/$dishId/');
    final status = resp.data['video_status'] as String;
    if (status == 'ready' || status == 'failed') return status;
  }
}
```

**Статусы видео:**

| Статус | Что показывать |
|---|---|
| `pending` | Прогресс-индикатор «Видео в очереди...» |
| `processing` | Прогресс-индикатор «Транскодирование...» |
| `ready` | Плеер с `video_url` |
| `failed` | Сообщение об ошибке + кнопка повторной загрузки |

Ориентировочное время транскодирования: до 30 сек видео — 5–15 сек; 1–3 мин видео — 30–90 сек.

---

### 6.8 Events & News CRUD (Staff Only)

Контент-менеджеры и администраторы могут создавать, редактировать и удалять мероприятия и новости напрямую из мобильного приложения.

**Base URLs:**
- Мероприятия: `/api/v1/events/admin/events/`
- Новости: `/api/v1/events/admin/news/`

Все эндпоинты требуют `Authorization: Bearer <access_token>` и `is_staff=true`. Пагинация отключена — возвращается плоский список.

---

#### Мероприятия (EventEditScreen)

**Список всех мероприятий (включая неактивные):**
```dart
final resp = await dio.get('/api/v1/events/admin/events/');
// resp.data — List<dynamic>, отсортирован по убыванию date_time
```

**Создать мероприятие** (`multipart/form-data`, `image` обязателен):
```dart
Future<void> createEvent({
  required String title,
  required String description,
  required DateTime dateTime,
  required File imageFile,
  String format = 'open',    // 'open' | 'closed'
  String? price,             // null = вход свободный
  int maxPlaces = 0,         // 0 = без ограничений
  bool isActive = true,
}) async {
  final formData = FormData.fromMap({
    'title': title,
    'description': description,
    'date_time': dateTime.toIso8601String(),
    'format': format,
    if (price != null) 'price': price,
    'max_places': maxPlaces,
    'is_active': isActive,
    'image': await MultipartFile.fromFile(
      imageFile.path,
      filename: path.basename(imageFile.path),
    ),
  });
  await dio.post('/api/v1/events/admin/events/', data: formData);
}
```

**Частичное обновление** (без смены обложки — JSON, со сменой — multipart):
```dart
// Скрыть мероприятие (JSON)
await dio.patch(
  '/api/v1/events/admin/events/$eventId/',
  data: {'is_active': false},
  options: Options(contentType: 'application/json'),
);

// Заменить обложку (multipart)
final formData = FormData.fromMap({
  'image': await MultipartFile.fromFile(newImage.path),
});
await dio.patch('/api/v1/events/admin/events/$eventId/', data: formData);
```

**Удалить мероприятие:**
```dart
await dio.delete('/api/v1/events/admin/events/$eventId/');
// 204 — тело пустое. Обложка удаляется из storage автоматически.
```

**Поля ответа** (`StaffEventSerializer`):

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | ID |
| `title` | string | Заголовок |
| `description` | text | Описание |
| `date_time` | datetime | ISO 8601 с timezone |
| `image` | file | write-only при upload |
| `image_url` | string | Абсолютный URL обложки (read) |
| `format` | string | `"open"` или `"closed"` |
| `price` | decimal / null | `null` = вход свободный |
| `is_active` | bool | Видимость в публичных эндпоинтах |
| `max_places` | int | `0` = без ограничений |
| `occupied_places` | int | Вычисляемое (read) |
| `created_at` | datetime | Дата создания (read) |

---

#### Новости (NewsEditScreen)

**Список всех новостей:**
```dart
final resp = await dio.get('/api/v1/events/admin/news/');
// resp.data — List<dynamic>, отсортирован по убыванию created_at
```

**Создать новость** (`image` необязателен):
```dart
Future<void> createNews({
  required String title,
  required String content,
  File? imageFile,  // null — новость без картинки допустима
}) async {
  final map = <String, dynamic>{
    'title': title,
    'content': content,
  };
  if (imageFile != null) {
    map['image'] = await MultipartFile.fromFile(imageFile.path);
  }

  // Если есть изображение — multipart; иначе можно JSON
  if (imageFile != null) {
    await dio.post('/api/v1/events/admin/news/', data: FormData.fromMap(map));
  } else {
    await dio.post(
      '/api/v1/events/admin/news/',
      data: {'title': title, 'content': content},
      options: Options(contentType: 'application/json'),
    );
  }
}
```

**Удалить новость:**
```dart
await dio.delete('/api/v1/events/admin/news/$newsId/');
// 204 — изображение удаляется из storage автоматически.
```

**Поля ответа** (`StaffNewsSerializer`):

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | ID |
| `title` | string | Заголовок |
| `content` | text | Текст новости |
| `image` | file | write-only при upload |
| `image_url` | string / null | Абсолютный URL изображения (read); `null` если нет фото |
| `created_at` | datetime | Дата публикации (read) |

---

### 6.9 Коды ошибок Admin API

| Код | Причина |
|---|---|
| `400` | Нет `image` при создании мероприятия или блюда; недопустимый `format` у события; неподдерживаемый тип видеофайла |
| `401` | Токен не передан или истёк |
| `403` | Пользователь не авторизован или `is_staff=false` |
| `404` | Объект с указанным `id` не существует |

---

## 🔁 7. Идемпотентность (защита от дублей при ретраях)

POST-запросы на создание брони и записи на мероприятие **обязательно** требуют заголовок `Idempotency-Key`.

### Как работает

1. Перед отправкой запроса сгенерируй UUID один раз: `final key = const Uuid().v4();`
2. Передай его в заголовке: `'Idempotency-Key': key`
3. Если соединение оборвалось — повтори запрос с **тем же** UUID.
4. Бэкенд вернёт тот же ответ (201 + тело), не создавая дубль.

```dart
final idempotencyKey = const Uuid().v4(); // сохраняем до получения ответа

final response = await dio.post(
  '/api/v1/bookings/',
  data: payload,
  options: Options(headers: {'Idempotency-Key': idempotencyKey}),
);
```

**Ошибки:**
| Код | Причина |
|---|---|
| `400` | Заголовок не передан или значение не является UUID |
| `409` | Запрос уже обрабатывается (конкурентный ретрай) — подожди 1–2 сек и повтори |

**Применяется к:**
- `POST /api/v1/bookings/`
- `POST /api/v1/events/reservations/create/`

---

## 🛑 8. Обработка ошибок в приложении (Важно)

1. **401 Unauthorized**: Access-токен истёк.
   - *Действие:* Вызови `POST /api/v1/users/auth/token/refresh/` с сохранённым refresh-токеном. Если refresh тоже вернул 401 — разлогинь пользователя и отправь на экран SMS-входа. Подробная схема — в разделе 1.3.
2. **400 Bad Request**: Ошибка валидации формы.
   - В ответе будет JSON вида: `{"phone": ["Неверный формат номера."]}`. Это нужно парсить и показывать под полями ввода.
3. **500 Server Error**: Бэкенд упал. 
   - *Действие:* Покажи пользователю Snack-bar "Что-то пошло не так, мы уже чиним". Ошибка автоматически запишется в логи сервера.
4. **503 Service Unavailable**: Инфраструктурная ошибка (Redis недоступен).
   - *Действие:* Покажи "Сервис временно недоступен. Попробуйте через несколько минут." Это не баг приложения.
5. **429 Too Many Requests**: Превышен лимит запросов.
   - Глобальные лимиты (все эндпоинты): анонимные — 60 запросов/мин, авторизованные — 300 запросов/мин.
   - Дополнительные лимиты SMS: 3 запроса/мин по IP, 5 запросов/10 мин по номеру телефона.
   - *Действие:* Для SMS-экрана показывай таймер. Для остальных — Snack-bar «Слишком много запросов, попробуйте через минуту».

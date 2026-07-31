# Core Info

Публичные данные ресторана: адрес, часы, hero-слайды, галерея интерьера.

## Эндпоинты

| Метод | Путь | Модель |
|--------|------|--------|
| GET | `/core/info/` | `CoreInfo` |
| GET | `/core/interior/` | `List<InteriorSlide>` |
| GET | `/core/app-version/?platform=ios\|android` | `AppVersionInfo` |

Клиент: `CoreRepository` → `DioClient.instance.dio`.

## CoreInfoProvider

- Вызывается при старте: `CoreInfoProvider()..load()` в `lib/main.dart`.
- `load()` за один вызов грузит **и** `GET /core/info/`, **и** `GET /core/interior/` (`Future.wait`) — результат кладётся в `coreInfo` и отдельное поле `interiorSlides` (галерея интерьера, используется вне этого документа экраном интерьера).
- `load()` не делает повторный запрос, если `isLoading == true` **или** `coreInfo != null` — т.е. без явного `reload()`/`retry()` данные грузятся ровно один раз за время жизни провайдера.
- При ошибке (`catch`) `coreInfo` сбрасывается в `null`, а `error` — в текст из `dioErrorMessage(e)`; повторный вызов `load()` после ошибки сработает (т.к. `coreInfo == null`), а `retry()`/`reload()` явно обнуляют состояние и грузят заново.
- **Fallback устроен по-разному для разных полей**, единого fallback-объекта `kRestaurantInfo` целиком нет:
  - `isOpenNow` и `workingHoursDisplay` (геттеры провайдера) при `coreInfo == null` подставляют `kRestaurantInfo.isOpen` / `kRestaurantInfo.hoursLabel` из `lib/core/home_data.dart`;
  - `heroImageUrls` при отсутствии данных возвращает **пустой список** (не `kRestaurantInfo`) — сам локальный fallback-цикл картинок (`PiligrimInteriorAssets.homeHeroCycle`) зашит в `HomeHeroSection`/`CrossfadingHeroInterior` и включается автоматически, когда сетевой список пуст;
  - все остальные поля (`address`, `phone`, `socialLinks`, `twogisLink`, `termsOfService`, `feedbackUrl`, `visitRules`, `privacyPolicy` и т.д.) фолбэка на уровне провайдера не имеют — экраны читают их через `core.coreInfo?.поле`, и при `coreInfo == null` просто получают `null` (см. таблицу «Использование в UI»).

## Поля модели CoreInfo

Из `GET /core/info/` (`lib/data/models/core_info.dart`):

| Поле модели | JSON | Nullable | Назначение |
|-------------|------|----------|------------|
| `address` | `address` | нет | Адрес заведения |
| `workingHours` | `working_hours` | нет | Часы работы (строка-лейбл) |
| `workingHoursNote` | `working_hours_note` | да | Доп. примечание к часам (напр. «по записи») |
| `isOpenNow` | `is_open_now` | нет | Открыто ли сейчас |
| `phone` | `phone` | нет | Телефон заведения |
| `socialLinks` | `social_links` (или legacy `whatsapp`/`telegram`/`instagram`) | список может быть пустым | Мессенджеры/соцсети; если бэкенд не отдаёт `social_links` списком, модель сама собирает список из плоских полей `whatsapp`/`telegram`/`instagram` |
| `heroSlides` | `hero_slides` | список может быть пустым | Слайды hero-баннера главного экрана (используются через `heroImageUrls`) |
| `visitRules` | `visit_rules` | список может быть пустым | Правила посещения; принимает как массив объектов `{title, body}`, так и «плоскую» строку (тогда оборачивается в один `VisitRuleItem(title: 'Правила', body: text)`) |
| `privacyPolicy` | `privacy_policy` | нет (строка, может быть пустой) | Текст/ссылка политики конфиденциальности |
| `conceptDescription` | `concept_description` | да | Описание концепции заведения |
| `twogisLink` | `twogis_link` | да | Ссылка на 2ГИС (единственный картографический сервис — Google Maps/Яндекс.Карты убраны) |
| `feedbackUrl` | `feedback_url` | да | Обратная связь (WhatsApp, форма и т.д.) |
| `termsOfService` | `terms_of_service` | да | Пользовательское соглашение |
| `tourLink` | `tour_link` | да | 3D-тур (пока только в модели, UI — позже) |

`heroImageUrls` — вычисляемый геттер модели: `heroSlides.map((s) => s.imageUrl).where((url) => url.isNotEmpty)`.

Подключение в экранах — `profile_screen.dart` (`_ContactsCard`/картa, соцсети, ссылки) и `home_screen.dart` (hero + статус-строка). **`booking_screen.dart` `CoreInfoProvider` не использует вовсе.**

## Использование в UI

| Экран / виджет | Поле |
|----------------|------|
| `HomeStatusLine` (через `HomeScreen`) | `isOpenNow`, `workingHoursDisplay` + `workingHoursNote` |
| `HomeHeroSection` (через `HomeScreen`) | `heroImageUrls` (CDN), иначе локальный цикл `PiligrimInteriorAssets.homeHeroCycle` |
| `HomeScreen` (инлайн-ошибка) | `core.error`, `core.isLoading`, `core.retry()` — показывает `PiligrimInlineError` с кнопкой повтора |
| `ProfileScreen` (карточка контактов) | `phone` (fallback `kRestaurantPhone`), `address`, `twogisLink` (карта «2ГИС»), `socialLinks` (мессенджеры) |
| `_RulesCard` (`ProfileScreen`) | `visitRules` (с локальным fallback-текстом, если пусто), `privacyPolicy` |
| `ProfileScreen` (ссылки) | `termsOfService`, `feedbackUrl` |

## Fallback

Единого поведения нет — см. раздел «CoreInfoProvider» выше: часы/статус подменяются моковыми (`kRestaurantInfo`), hero-изображения — локальным циклом `PiligrimInteriorAssets.homeHeroCycle`, а остальные поля (адрес, ссылки, соцсети, правила) при недоступном API просто отсутствуют (`null`/пустой список), и соответствующие блоки UI скрываются по условию (`if (coreInfo?.поле != null) ...`).

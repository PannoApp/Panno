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
- `load()` не делает повторный запрос, если `coreInfo != null` или идёт загрузка.
- При ошибке сети UI использует **fallback** на `kRestaurantInfo` из `lib/core/home_data.dart`.

## Дополнительные поля (Ш-2)

Парсятся из `GET /core/info/` (nullable — если в админке пусто, в JSON `null`):

| Поле модели | JSON | Назначение |
|-------------|------|------------|
| `twogisLink` | `twogis_link` | Ссылка на 2ГИС |
| `googleMapsLink` | `google_maps_link` | Google Maps |
| `yandexMapsLink` | `yandex_maps_link` | Яндекс.Карты |
| `feedbackUrl` | `feedback_url` | Обратная связь (WhatsApp, форма и т.д.) |
| `termsOfService` | `terms_of_service` | Пользовательское соглашение |
| `tourLink` | `tour_link` | 3D-тур (пока только в модели, UI — позже) |

Подключение в экранах — блок **А-3** (`profile_screen`, `booking_screen`).

## Использование в UI

| Экран / виджет | Поле |
|----------------|------|
| `HomeStatusLine` | `isOpenNow`, `workingHours` (+ note) |
| `HomeHeroSection` | `heroImageUrls` (CDN), иначе локальные PNG |
| `ProfileScreen` `_HoursCard` | `workingHours`, `isOpenNow` |
| `ProfileScreen` (после А-3) | карты, `termsOfService`, `feedbackUrl` |

## Fallback

Если API недоступен — отображаются моковые часы и локальный цикл hero из `PiligrimInteriorAssets.homeHeroCycle`.

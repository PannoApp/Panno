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

## Использование в UI

| Экран / виджет | Поле |
|----------------|------|
| `HomeStatusLine` | `isOpenNow`, `workingHours` (+ note) |
| `HomeHeroSection` | `heroImageUrls` (CDN), иначе локальные PNG |
| `ProfileScreen` `_HoursCard` | `workingHours`, `isOpenNow` |

## Fallback

Если API недоступен — отображаются моковые часы и локальный цикл hero из `PiligrimInteriorAssets.homeHeroCycle`.

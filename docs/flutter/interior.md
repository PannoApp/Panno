# Экран «Интерьер» — Flutter-документация

## Обзор

`InteriorScreen` — вкладка #2 в `RootShell` (IndexedStack). Показывает фотогалерею ресторана с возможностью:
- просмотра по зонам (Главный зал, Терраса, Бар, …)
- fullscreen просмотра с pinch-to-zoom и листанием
- открытия 3D-тура в браузере (если настроен в админке)
- воспроизведения атмосферного фонового аудио — **только на время открытого 3D-тура**, не при простом открытии вкладки

## Файлы

| Файл | Роль |
|------|------|
| `lib/screens/interior_screen.dart` | Основной экран + `_TourButton`, `_InteriorSlideTile` |
| `lib/screens/interior_photo_viewer.dart` | Fullscreen просмотрщик с `InteractiveViewer` |
| `lib/widgets/interior_zone_filter.dart` | Горизонтальный фильтр по зонам |
| `lib/screens/interior_screen.dart` (`_CompactAudioButton`, приватный класс) | Кнопка mute/unmute атмосферного аудио — отдельного файла `interior_audio_button.dart` не существует |

## Источники данных

| Данные | Откуда |
|--------|--------|
| `interiorSlides` | `CoreInfoProvider.interiorSlides` (из `GET /api/v1/core/interior/`) |
| `tourLink` | `CoreInfoProvider.coreInfo?.tourLink` (из `GET /api/v1/core/info/`) |

Оба запроса выполняются параллельно в `CoreInfoProvider.load()` при старте приложения.

### Поведение без данных API (`useApi = false`)

Локального PNG-фолбэка на этом экране фактически нет. `useApi = slides.isNotEmpty`; если `CoreInfoProvider.interiorSlides` пуст (ошибка сети или пустой ответ), `filtered`/`gridSlides` остаются пустыми списками и сетка/hero-фото просто не рендерятся — вместо галереи показывается пустой `SizedBox(height: 120)`. Если при этом есть `core.error`, сверху выводится `PiligrimInlineError` с текстом «Показаны локальные фото» и кнопкой повтора — но сами локальные фото при этом не показываются, текст ошибки не соответствует реальному поведению.

В файле определён класс `_AssetPhotoViewer` (полноэкранный просмотрщик для локальных ассетов из `PiligrimInteriorAssets`) — он нигде не создаётся (`grep` по `_AssetPhotoViewer` не находит вызовов конструктора за пределами объявления класса) и является мёртвым кодом. `PiligrimInteriorAssets` ([lib/core/interior_assets.dart](../../lib/core/interior_assets.dart)) используется на этом экране только через `decodeCacheWidth()` для расчёта `memCacheWidth` сетевых изображений.

## Фильтрация по зонам

В `build()` из списка `slides` вычисляются уникальные зоны:

```dart
final zones = slides
    .map((s) => (zone: s.zone, label: s.zoneDisplay))
    .toSet()
    .toList();
```

Состояние фильтра — `String? _selectedZone` в `_InteriorScreenState`.  
`null` — показывать все фото; непустая строка — только фото выбранной зоны.

Фильтр по зонам (`InteriorZoneFilter`) отображается только если `zones.length > 1`.

## Fullscreen просмотр (`InteriorPhotoViewer`)

Открывается через `PageRouteBuilder` с `FadeTransition + ScaleTransition(begin: 0.93)`:

```dart
Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black87,
    pageBuilder: (_, __, ___) => InteriorPhotoViewer(
      slides: filtered,   // отфильтрованные фото текущей зоны
      initialIndex: i,
    ),
    ...
  ),
);
```

### Жесты в просмотрщике

| Жест | Действие |
|------|----------|
| Pinch / double-tap | Zoom (1.0–4.0) через `InteractiveViewer` |
| Горизонтальный свайп | Листание между фото (`PageView`) |
| Быстрый свайп вниз (velocity > 400) | Закрытие |
| Медленный drag вниз (> 100px) | Закрытие |
| Медленный drag, отпустить раньше | Пружина обратно |
| Кнопка X (верхний правый) | Закрытие |

В просмотрщике снизу отображается:
- `slide.zoneDisplay` — название зоны (заглавными, цвет `steppe`)
- `slide.caption` — подпись (если непустая)

## Атмосферное аудио

### Файл

`assets/audio/interior_ambient.mp3` — зацикленный эмбиент (рекомендуемые параметры: 30–60 сек, mono, 128 kbps, ≤ 500 KB). Файл воспроизводится через `audioplayers: ^6.1.0`.

### Lifecycle

Аудио управляется в `_InteriorScreenState`, который живёт постоянно (вкладка в `IndexedStack` + `wantKeepAlive = true`). **Аудио НЕ запускается при открытии вкладки «Интерьер»** — это явное решение, закреплённое комментарием в коде: `initState()` только создаёт `AudioPlayer` и подписывается на `WidgetsBindingObserver`, но не вызывает `_startAmbientAudio()` (`// Аудио не запускается при открытии экрана — только при старте 3D-тура`). Реальный триггер — открытие и закрытие 3D-тура (`_openTour`).

| Событие | Действие |
|---------|----------|
| `initState()` | Только создаётся `AudioPlayer` и регистрируется `WidgetsBindingObserver`; аудио НЕ стартует |
| `_openTour(url)`, аудио ещё не инициализировано | `_startAmbientAudio()` запускается перед открытием `TourWebViewScreen` |
| `_openTour(url)`, аудио уже инициализировано, но замьючено | `_audioPlayer.resume()` перед открытием тура |
| `_startAmbientAudio()` успех | `_audioInitialized = true` → кнопка `_CompactAudioButton` появляется |
| `_startAmbientAudio()` ошибка | `_audioInitialized` остаётся `false` → кнопка скрыта, UI не ломается |
| Возврат из `TourWebViewScreen` (тур закрыт) | `_audioPlayer.stop()`, затем `_audioInitialized = false` и `_isMuted = false` (сброс) → кнопка скрывается |
| `didUpdateWidget`: `isTabActive` false → true (аудио уже инициализировано) | `_audioPlayer.resume()` (если не замьючено) |
| `didUpdateWidget`: `isTabActive` true → false (аудио уже инициализировано) | `_audioPlayer.pause()` |
| `didChangeAppLifecycleState`: paused (аудио уже инициализировано) | `_audioPlayer.pause()` |
| `didChangeAppLifecycleState`: resumed (аудио уже инициализировано) | `_audioPlayer.resume()` (если не замьючено) |
| `dispose()` | `_audioPlayer.stop()` + `_audioPlayer.dispose()` |

Обработчики `didUpdateWidget` / `didChangeAppLifecycleState` реагируют, только если `_audioInitialized == true` — то есть до открытия тура ни переключение вкладок, ни сворачивание приложения на аудио не влияют (его просто ещё нет).

`WidgetsBindingObserver` добавляется в `initState()` и удаляется в `dispose()`.

### Параметр `isTabActive`

```dart
class InteriorScreen extends StatefulWidget {
  const InteriorScreen({super.key, this.isTabActive = true});
  final bool isTabActive;
}
```

Передаётся из `RootShell` (`lib/main.dart`):
```dart
InteriorScreen(isTabActive: _currentIndex == 2),
```

Паттерн аналогичен `MenuScreen(isTabActive: _currentIndex == 1)`.

## 3D-тур

Кнопка «Виртуальный 3D-тур» отображается только при непустом `tourLink`:

```dart
if (tourLink != null && tourLink.isNotEmpty)
  SliverToBoxAdapter(child: _TourButton(onTap: () => _openTour(tourLink)));
```

Нажатие вызывает `url_launcher`:
```dart
launchUrl(uri, mode: LaunchMode.externalApplication)
```

Открывается в системном браузере (WebView не требуется). При ошибке — `SnackBar`.

## Чек-лист ручного тестирования

**3D-тур:**
- [ ] Кнопка отображается только при `tourLink != null` (задать в Django Admin → RestaurantInfo)
- [ ] Нажатие открывает системный браузер
- [ ] При отсутствии `tourLink` — кнопка полностью скрыта

**Фильтр зон:**
- [ ] Фильтр скрыт, если все фото в одной зоне (или фото нет)
- [ ] «Все» показывает полный список
- [ ] Выбор зоны мгновенно фильтрует сетку
- [ ] При смене зоны просмотрщик открывается в рамках отфильтрованных фото

**Fullscreen просмотр:**
- [ ] Тап открывает просмотрщик на правильном индексе
- [ ] Pinch-to-zoom работает (1.0–4.0)
- [ ] Горизонтальное листание PageView
- [ ] `caption` виден только если непустой
- [ ] Свайп вниз (быстрый) закрывает
- [ ] Кнопка X закрывает

**Аудио:**
- [ ] Аудио НЕ запускается при простом открытии вкладки «Интерьер» (только после старта тура)
- [ ] Нажатие «Виртуальный тур» запускает аудио перед переходом в `TourWebViewScreen`
- [ ] Возврат из тура останавливает аудио и скрывает кнопку (сброс `_audioInitialized`/`_isMuted`)
- [ ] Пока тур не открыт хотя бы раз, переключение вкладок / сворачивание приложения не влияет на аудио (его ещё нет)
- [ ] После открытия тура: переключение на другую вкладку — пауза
- [ ] После открытия тура: возврат — возобновление (если не замьючено вручную)
- [ ] После открытия тура: сворачивание приложения — пауза
- [ ] Кнопка `_CompactAudioButton` переключает mute/unmute
- [ ] При отсутствии `interior_ambient.mp3` — кнопка скрыта, экран работает корректно
- [ ] Открытие фото-просмотрщика (`InteriorPhotoViewer`) не прерывает аудио
